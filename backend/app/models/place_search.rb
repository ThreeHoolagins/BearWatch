require "net/http"

# Place lookup for the post form, backed by OpenStreetMap's Nominatim
# (https://nominatim.org). Requests go from our server, so visitors' browsers
# never talk to a third party.
#
# Nominatim's usage policy (https://operations.osmfoundation.org/policies/nominatim/):
# at most 1 request per second, an identifying User-Agent, cache results, and
# no search-as-you-type. So the form searches when the person presses Search,
# we throttle to one request a second, and cache answers for a day.
#
# Results are labelled the way they show under a post: "Fort Collins, CO",
# "Katmai National Park, AK".
class PlaceSearch
  class Unavailable < StandardError; end

  Place = Data.define(:name, :latitude, :longitude)

  ENDPOINT = URI("https://nominatim.openstreetmap.org/")
  # Towns, parks, reserves and natural features; skip streets, shops and buildings.
  CATEGORIES = %w[place boundary leisure natural tourism].freeze
  MIN_INTERVAL = 1.1 # seconds between requests to Nominatim

  US_STATES = {
    "Alabama" => "AL", "Alaska" => "AK", "Arizona" => "AZ", "Arkansas" => "AR", "California" => "CA",
    "Colorado" => "CO", "Connecticut" => "CT", "Delaware" => "DE", "Florida" => "FL", "Georgia" => "GA",
    "Hawaii" => "HI", "Idaho" => "ID", "Illinois" => "IL", "Indiana" => "IN", "Iowa" => "IA", "Kansas" => "KS",
    "Kentucky" => "KY", "Louisiana" => "LA", "Maine" => "ME", "Maryland" => "MD", "Massachusetts" => "MA",
    "Michigan" => "MI", "Minnesota" => "MN", "Mississippi" => "MS", "Missouri" => "MO", "Montana" => "MT",
    "Nebraska" => "NE", "Nevada" => "NV", "New Hampshire" => "NH", "New Jersey" => "NJ", "New Mexico" => "NM",
    "New York" => "NY", "North Carolina" => "NC", "North Dakota" => "ND", "Ohio" => "OH", "Oklahoma" => "OK",
    "Oregon" => "OR", "Pennsylvania" => "PA", "Rhode Island" => "RI", "South Carolina" => "SC",
    "South Dakota" => "SD", "Tennessee" => "TN", "Texas" => "TX", "Utah" => "UT", "Vermont" => "VT",
    "Virginia" => "VA", "Washington" => "WA", "West Virginia" => "WV", "Wisconsin" => "WI", "Wyoming" => "WY",
    "District of Columbia" => "DC"
  }.freeze

  @throttle = Mutex.new
  @last_request_at = 0.0

  class << self
    # Spaces requests out to Nominatim's one-per-second limit (per process;
    # we run a single web process).
    def throttled
      @throttle.synchronize do
        wait = @last_request_at + MIN_INTERVAL - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        sleep(wait) if wait.positive?
        @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
      yield
    end

    # Nominatim results -> labelled, de-duplicated places.
    def places_from(results)
      Array(results).filter_map { |result| place_from(result) }.uniq(&:name)
    end

    def place_from(result, name: nil)
      return unless CATEGORIES.include?(result["category"])

      address = result["address"] || {}
      name ||= result["name"].presence
      lat, lon = Float(result["lat"], exception: false), Float(result["lon"], exception: false)
      return unless name && lat && lon

      region =
        if address["country_code"] == "us" then US_STATES[address["state"]] || address["state"]
        else [ address["state"], address["country"] ].compact_blank.uniq.join(", ")
        end
      label = [ name, region ].compact_blank.uniq.join(", ").first(120)
      Place.new(name: label, latitude: lat.round(1), longitude: lon.round(1))
    end
  end

  def search(query)
    self.class.places_from(get("search", q: query, format: "jsonv2", addressdetails: 1, limit: 10, "accept-language": "en"))
  end

  # The town or city around a point, for "Use where I am now".
  def reverse(latitude, longitude)
    result = get("reverse", lat: latitude, lon: longitude, format: "jsonv2", zoom: 10, addressdetails: 1, "accept-language": "en")
    return if result.is_a?(Hash) && result["error"]

    address = result["address"] || {}
    town = address["city"] || address["town"] || address["village"] || address["hamlet"] || address["county"]
    self.class.place_from(result.merge("category" => "place"), name: town)
  end

  private
    def get(path, params)
      uri = URI.join(ENDPOINT, path)
      uri.query = URI.encode_www_form(params)
      Rails.cache.fetch([ "nominatim", uri.to_s ], expires_in: 1.day) do
        response = self.class.throttled do
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 8) do |http|
            http.get(uri.request_uri, "User-Agent" => user_agent, "Accept" => "application/json")
          end
        end
        raise Unavailable, "nominatim returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      end
    rescue SystemCallError, IOError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError, JSON::ParserError => error
      raise Unavailable, "nominatim unreachable: #{error.class}"
    end

    # Nominatim asks for an identifying User-Agent with a way to reach us.
    def user_agent
      contact = ENV["GEOCODER_CONTACT"].presence || ENV["APP_HOST"].presence || "localhost"
      "BearWatch/1.0 (#{contact})"
    end
end
