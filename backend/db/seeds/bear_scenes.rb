# Draws stand-in "bear photos" for development seeds: a landscape with one or
# more bear silhouettes, rendered from SVG to WebP with libvips. Nothing is
# downloaded, so there are no photo licenses to worry about.
#
# Because we draw the bear ourselves we know exactly where it is, so each
# scene also returns a bear box like the real detector would.
module BearScenes
  WIDTH = 1200
  HEIGHT = 900

  # Bear silhouette facing right, in a 120 x 70 box (head around x=99, y=24).
  BEAR_PATH = "M8,64 C6,44 16,30 36,27 C50,19 76,18 90,27 C96,22 106,23 111,31 C117,34 119,41 114,45 " \
              "L105,47 C103,52 101,58 101,66 L92,66 L89,53 C79,57 61,57 49,55 L47,66 L38,66 L36,55 " \
              "C31,57 27,61 27,66 L17,66 Z"
  BEAR_BOUNDS = { x: 6, y: 18, w: 113, h: 48 } # the path's extent inside the 120 x 70 box

  PALETTES = {
    meadow: { sky: %w[#a9d1e8 #e9f3f2], far: "#8fae9f", near: "#5f8a52", ground: "#7da35a", sun: "#f3c969", bear: "#4a3324" },
    river:  { sky: %w[#9fc0cc #dce8e6], far: "#7f9c94", near: "#4f6f4a", ground: "#4f7381", sun: "#f3e2a8", bear: "#2e2118" },
    golden: { sky: %w[#f2c98f #f7e6c4], far: "#b9935b", near: "#8d7b3b", ground: "#b9a55c", sun: "#f08a3c", bear: "#5a3a22" },
    forest: { sky: %w[#7d9c8a #c9d8c8], far: "#4f6b52", near: "#2c4030", ground: "#3b5640", sun: "#e8e2b0", bear: "#1a1410" },
    snow:   { sky: %w[#b8c9d6 #eef3f6], far: "#9aaab3", near: "#c9d4d8", ground: "#eef2f4", sun: "#fff6d8", bear: "#4a3324" },
    dusk:   { sky: %w[#5b4a7a #f0a87a], far: "#5e5a6e", near: "#3c3a48", ground: "#4d5a46", sun: "#f7c873", bear: "#21170f" }
  }.freeze

  # bear_box: centre x, centre y, width, height; head: x, y. All 0-1 of the picture.
  Scene = Data.define(:svg, :bear_box, :head)

  module_function

  # rng: a Random so the same seed always draws the same pictures.
  def build(rng, palette: PALETTES.keys.sample(random: rng), cubs: rng.rand < 0.25)
    colors = PALETTES.fetch(palette)
    flip = rng.rand < 0.5
    scale = rng.rand(4.0..6.5)
    bear_w = 120 * scale
    x = rng.rand(80.0..(WIDTH - bear_w - 80))
    y = HEIGHT * 0.78 - 66 * scale + rng.rand(-20.0..30.0)

    shapes = [ sky(colors), sun(rng, colors), ridge(rng, colors[:far], HEIGHT * 0.42, 120),
               ridge(rng, colors[:near], HEIGHT * 0.58, 60), ground(colors), trees(rng, colors) ]
    shapes << bear(x, y, scale, flip, colors[:bear])
    if cubs
      cub_scale = scale * 0.45
      cub_x = flip ? x - 120 * cub_scale * 0.7 : x + bear_w - 120 * cub_scale * 0.3
      shapes << bear(cub_x.clamp(10, WIDTH - 120 * cub_scale - 10), y + 66 * (scale - cub_scale), cub_scale, flip, colors[:bear])
    end

    svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}" viewBox="0 0 #{WIDTH} #{HEIGHT}">#{shapes.join}</svg>)
    Scene.new(svg:, bear_box: box(x, y, scale, flip), head: head(x, y, scale, flip))
  end

  # Writes the scene as a WebP via vipsthumbnail. SVG loading is off by default
  # (VIPS_BLOCK_UNTRUSTED); it's fine here because we wrote the SVG ourselves.
  def render(scene, destination)
    Dir.mktmpdir do |dir|
      svg_path = File.join(dir, "scene.svg")
      File.write(svg_path, scene.svg)
      _, err, status = Open3.capture3({ "VIPS_BLOCK_UNTRUSTED" => nil }, "vipsthumbnail", svg_path,
                                      "--size", "#{WIDTH}x#{HEIGHT}", "-o", "#{destination}[Q=80,strip]")
      raise "vipsthumbnail failed: #{err}" unless status.success?
    end
    [ WIDTH, HEIGHT ]
  end

  # Centre and size of the big bear, as fractions of the picture.
  def box(x, y, scale, flip)
    local_left = flip ? 120 - BEAR_BOUNDS[:x] - BEAR_BOUNDS[:w] : BEAR_BOUNDS[:x]
    left = x + local_left * scale
    top = y + BEAR_BOUNDS[:y] * scale
    w = BEAR_BOUNDS[:w] * scale
    h = BEAR_BOUNDS[:h] * scale
    [ (left + w / 2) / WIDTH, (top + h / 2) / HEIGHT, w / WIDTH, h / HEIGHT ].map { _1.round(4) }
  end

  def head(x, y, scale, flip)
    hx = x + (flip ? 120 - 99 : 99) * scale
    hy = y + 30 * scale
    [ (hx / WIDTH).round(4), (hy / HEIGHT).round(4) ]
  end

  def sky(colors)
    %(<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#{colors[:sky][0]}"/>) +
      %(<stop offset="1" stop-color="#{colors[:sky][1]}"/></linearGradient></defs><rect width="#{WIDTH}" height="#{HEIGHT}" fill="url(#sky)"/>)
  end

  def sun(rng, colors)
    %(<circle cx="#{rng.rand(150..1050)}" cy="#{rng.rand(90..220)}" r="#{rng.rand(40..75)}" fill="#{colors[:sun]}" opacity=".9"/>)
  end

  def ridge(rng, color, base, jag)
    points = [ [ 0, HEIGHT ], [ 0, base ] ]
    x = 0
    while x < WIDTH
      x += rng.rand(90..180)
      points << [ [ x, WIDTH ].min, base - rng.rand(0..jag * 2) + jag / 2 ]
    end
    points << [ WIDTH, HEIGHT ]
    %(<polygon fill="#{color}" points="#{points.map { |px, py| "#{px.round},#{py.round}" }.join(" ")}"/>)
  end

  def ground(colors)
    %(<rect y="#{(HEIGHT * 0.68).round}" width="#{WIDTH}" height="#{(HEIGHT * 0.32).round}" fill="#{colors[:ground]}"/>)
  end

  def trees(rng, colors)
    Array.new(rng.rand(4..9)) do
      tx = rng.rand(0..WIDTH)
      size = rng.rand(40..110)
      base = HEIGHT * 0.66 + rng.rand(-30..20)
      %(<polygon fill="#{colors[:near]}" opacity=".95" points="#{tx},#{(base - size * 2).round} #{tx - size / 2},#{base.round} #{tx + size / 2},#{base.round}"/>)
    end.join
  end

  def bear(x, y, scale, flip, color)
    transform = flip ? "translate(#{(x + 120 * scale).round(1)},#{y.round(1)}) scale(#{-scale.round(3)},#{scale.round(3)})" :
                       "translate(#{x.round(1)},#{y.round(1)}) scale(#{scale.round(3)})"
    %(<g transform="#{transform}" fill="#{color}"><path d="#{BEAR_PATH}"/><circle cx="99" cy="24" r="4.5"/></g>)
  end
end
