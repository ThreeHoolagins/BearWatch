require "net/http"

# Talks to the detector container (see detector/server.py).
class BearDetectorClient
  # The detector is down or busy; worth retrying later.
  class Unavailable < StandardError; end
  # The detector couldn't read the image.
  class Unreadable < StandardError; end

  Verdict = Data.define(:is_bear, :bear_score, :person_detected, :person_score, :runner_up, :runner_up_score, :bear_box) do
    def initialize(bear_box: nil, **rest) = super(bear_box:, **rest)
  end

  def initialize(url: ENV.fetch("DETECTOR_URL", "http://detector:8000"))
    @uri = URI.join(url, "/detect")
  end

  def detect(image_bytes)
    response = Net::HTTP.start(@uri.host, @uri.port, open_timeout: 5, read_timeout: 60) do |http|
      http.post(@uri.path, image_bytes, "Content-Type" => "application/octet-stream")
    end

    case response
    when Net::HTTPSuccess
      body = JSON.parse(response.body)
      Verdict.new(**body.slice(*Verdict.members.map(&:to_s)).transform_keys(&:to_sym))
    when Net::HTTPClientError
      raise Unreadable, "detector could not read the image (#{response.code})"
    else
      raise Unavailable, "detector returned #{response.code}"
    end
  rescue SystemCallError, IOError, Timeout::Error, SocketError => error
    raise Unavailable, "detector unreachable: #{error.class}: #{error.message}"
  end
end
