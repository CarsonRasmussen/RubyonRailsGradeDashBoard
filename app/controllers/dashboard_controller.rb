require "net/http"
require "json"

class DashboardController < ApplicationController
  def index
    begin
      token = ENV["CANVAS_API_TOKEN"]

      if token.blank?
        @courses = []
        @error = "Canvas API token is missing."
        return
      end

      # Get favorite courses
      courses_url = "https://boisestatecanvas.instructure.com/api/v1/users/self/favorites/courses"
      @courses = get_all_pages(courses_url, token)

      # Calculate GPA using all favorite courses
      grade_points = []

      @courses.each do |course|
        grades_url = "https://boisestatecanvas.instructure.com/api/v1/courses/#{course["id"]}/enrollments?user_id=self"
        enrollments = get_all_pages(grades_url, token)

        if enrollments.any?
          grade = enrollments[0].dig("grades", "current_score")

          if grade
            grade_points << calculate_grade_points(grade)
          end
        end
      end

      if grade_points.any?
        @overall_gpa = (grade_points.sum / grade_points.length).round(2)
      end

      # Get grade for selected course
      if params[:course_id].present?
        grades_url = "https://boisestatecanvas.instructure.com/api/v1/courses/#{params[:course_id]}/enrollments?user_id=self"
        enrollments = get_all_pages(grades_url, token)

        if enrollments.any?
          @grade = enrollments[0].dig("grades", "current_score")
        end
      end

    rescue
      @courses = []
      @error = "Could not connect to Canvas."
    end
  end

  private

  def calculate_grade_points(grade)
    if grade >= 90
      4.0
    elsif grade >= 80
      3.0
    elsif grade >= 70
      2.0
    elsif grade >= 60
      1.0
    else
      0.0
    end
  end

  def get_all_pages(url, token)
    results = []

    while url
      uri = URI(url)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Canvas API error"
      end

      results.concat(JSON.parse(response.body))

      next_link = response["Link"]&.split(",")&.find do |link|
        link.include?('rel="next"')
      end

      url = next_link&.match(/<([^>]+)>/)&.[](1)
    end

    results
  end
end