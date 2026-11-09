# frozen_string_literal: true

require "application_system_test_case"

class ManageModerationZones < ApplicationSystemTestCase
  driven_by_selenium "default", :preferences => { "ui.prefersReducedMotion" => 1 }

  test "Create a moderation zone and fail to put an anonymous note within it" do
    sign_in_as(create(:moderator_user))

    visit moderation_zones_path
    click_on "New Moderation Zone"

    fill_in "Name", :with => "Test zone"
    fill_in "Reason", :with => "He's a very naughty boy"

    map = find_by_id("map")
    map.click(:offset => :center, :x => -50, :y => -50)
    map.click(:offset => :center, :x => 0, :y => -50)
    map.click(:offset => :center, :x => 0, :y => 0)
    map.click(:offset => :center, :x => -50, :y => 0)
    map.click(:offset => :center, :x => -50, :y => -50)

    select "1 week", :from => :moderation_zone_period
    click_on "Create Moderation zone"
    assert_content "Moderation zone created"

    sign_out
    visit new_note_path(:anchor => "map=18/7.15/-9.23")
    within_sidebar do
      fill_in "text", :with => "Hahaha! Nobody expects the Spanish anonymous notes!"
      click_on "Add Note"

      assert_content "There was an error when creating the note"
      find(".new-note-error summary").click
      assert_text "You don't have permissions to make changes here. Please either sign in or create an OpenStreetMap account"
    end
  end

  test "Revoke a moderation zone" do
    user = create(:moderator_user)
    zone = create(:moderation_zone, :creator => user)

    sign_in_as(user)
    visit edit_moderation_zone_path(zone)

    # Editing defaults to the absolute-expiry panel, which hides/disables
    # the period select used below.
    choose "For a duration"
    select "Revoke moderation zone", :from => :moderation_zone_period
    click_on "Update Moderation zone"
    assert_content "Moderation zone updated"

    zone.reload
    assert_equal user, zone.revoker
  end

  test "edit a fitted moderation zone polygon" do
    moderator = create(:moderator_user)
    zone = create(:moderation_zone, :seville_cathedral, :creator => moderator)
    original = zone.zone.exterior_ring.points.map { |point| [point.x, point.y] }
    sign_in_as(moderator)
    visit edit_moderation_zone_path(zone)

    map = find_by_id("map")
    field = find_by_id("moderation_zone_zone", :visible => :all)
    initial_value = field.value
    Selenium::WebDriver::Wait.new(:timeout => 15, :interval => 0.1).until do
      map.click(:offset => :center)
      # The fixture's first vertex is at this offset once the map fits the polygon.
      page.driver.browser.action.move_to(map.native, -65, -62).click_and_hold.move_by(-20, -10).release.perform
      field.value != initial_value
    end

    click_on "Update Moderation zone"
    assert_text "Moderation zone updated"
    updated = zone.reload.zone.exterior_ring.points.map { |point| [point.x, point.y] }
    assert_not_equal original.first, updated.first
    assert_equal original[1...-1], updated[1...-1]
    assert_equal updated.first, updated.last
    assert_in_delta original.first[0], updated.first[0], 0.001
    assert_in_delta original.first[1], updated.first[1], 0.001
  end
end
