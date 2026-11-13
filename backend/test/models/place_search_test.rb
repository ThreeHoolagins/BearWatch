require "test_helper"

class PlaceSearchTest < ActiveSupport::TestCase
  def result(name:, lat:, lon:, category: "place", **address)
    { "category" => category, "name" => name, "lat" => lat.to_s, "lon" => lon.to_s, "address" => address.transform_keys(&:to_s) }
  end

  test "labels US places with state abbreviations and rounds coordinates" do
    places = PlaceSearch.places_from([
      result(name: "Fort Collins", lat: 40.5853, lon: -105.0844, state: "Colorado", country_code: "us"),
      result(name: "Katmai National Park", lat: 58.6, lon: -155.0, category: "leisure", state: "Alaska", country_code: "us")
    ])

    assert_equal [ "Fort Collins, CO", "Katmai National Park, AK" ], places.map(&:name)
    assert_equal [ 40.6, -105.1 ], [ places.first.latitude, places.first.longitude ]
  end

  test "labels places outside the US with region and country" do
    place = PlaceSearch.places_from([ result(name: "Banff", lat: 51.17, lon: -115.57, state: "Alberta", country: "Canada", country_code: "ca") ]).first
    assert_equal "Banff, Alberta, Canada", place.name
  end

  test "skips streets and buildings, duplicates, and results without coordinates" do
    places = PlaceSearch.places_from([
      result(name: "Katmai", lat: 19.2, lon: -103.7, category: "highway", state: "Colima", country_code: "mx"),
      result(name: "Estes Park", lat: 40.37, lon: -105.52, state: "Colorado", country_code: "us"),
      result(name: "Estes Park", lat: 40.38, lon: -105.51, state: "Colorado", country_code: "us"),
      { "category" => "place", "name" => "Nowhere" }
    ])
    assert_equal [ "Estes Park, CO" ], places.map(&:name)
  end
end
