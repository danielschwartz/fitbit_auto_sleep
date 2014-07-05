require 'pry'
require 'mechanize'
require 'fitgem'
require 'time'
require 'action_mailer'

last_day_steps = nil
current_day_steps = nil
retries = 0

if ARGV[0] && ARGV[1]
    yesterday = Time.parse(ARGV[0])
    now = Time.parse(ARGV[1])
else
    yesterday = Date.today - 1
    now = Date.today
end

Mechanize.start do |m|
    begin
        m.get("https://www.fitbit.com/login") do |login_page|
            dashboard_page = login_page.form_with(:action => "https://www.fitbit.com/login") do |f|
                f.email = ENV["FITBIT_EMAIL"]
                f.password = ENV["FITBIT_PASSWORD"]
            end.submit
        end
    rescue
        retries += 1
        retry if retries < 1
    end

    m.get("http://www.fitbit.com/graph/getNewGraphData?userId=#{ENV["FITBIT_USER_ID"]}&type=intradaySteps&dateFrom=#{yesterday.year}-#{yesterday.month}-#{yesterday.day}&dateTo=#{yesterday.year}-#{yesterday.month}-#{yesterday.day}&apiFormat=json") do |json_data|
        last_day_steps = JSON.parse(json_data.body)
    end

    m.get("http://www.fitbit.com/graph/getNewGraphData?userId=#{ENV["FITBIT_USER_ID"]}&type=intradaySteps&dateFrom=#{now.year}-#{now.month}-#{now.day}&dateTo=#{now.year}-#{now.month}-#{now.day}&apiFormat=json") do |json_data|
        current_day_steps = JSON.parse(json_data.body)
    end
end

fitbit_api = Fitgem::Client.new({:consumer_key => ENV["FITBIT_APP_CONSUMER_KEY"], :consumer_secret => ENV["FITBIT_APP_CONSUMER_SECRET"]})

fitbit_api.reconnect(ENV["FITBIT_TOKEN"], ENV["FITBIT_SECRET"])

fitbit_api.intraday_time_series({ resource: :steps, date: '2014-01-01', detailLevel: '1min' })

all_data_points = []

last_day_steps["graph"]["dataSets"]["activity"]["dataPoints"].each { |data_point|  
    if Time.parse(data_point["dateTime"]) >= Time.parse("#{yesterday.year}-#{yesterday.month}-#{yesterday.day} 22:00:00")
        all_data_points.push(data_point)
    end
}

current_day_steps["graph"]["dataSets"]["activity"]["dataPoints"].each { |data_point|  
    if Time.parse(data_point["dateTime"]) <= Time.parse("#{now.year}-#{now.month}-#{now.day} 12:30:00")
        all_data_points.push(data_point)
    end
}

def get_sleep_change_point(array, threshold)
    possible_sleep_points = []

    array.each { |data_point|  
        if possible_sleep_points.length == threshold
            break
        end

        if data_point["value"] > 0
            possible_sleep_points = []
        end

        if data_point["value"] == 0
            possible_sleep_points.push(data_point)
        end
    }

    return possible_sleep_points[0]
end

start_sleep = get_sleep_change_point(all_data_points, ENV["FITBIT_BEGIN_SLEEP_THRESHOLD"].to_i)
end_sleep = get_sleep_change_point(all_data_points.reverse, ENV["FITBIT_END_SLEEP_THRESHOLD"].to_i)

start_sleep_time = Time.parse(start_sleep["dateTime"])
end_sleep_time = Time.parse(end_sleep["dateTime"])

sleep_obj = {
    "startTime" => "#{start_sleep_time.hour}:#{start_sleep_time.min}",
    "duration" => ((end_sleep_time - start_sleep_time) * 1000).to_i,
    "date" => "#{start_sleep_time.year}-#{start_sleep_time.month}-#{start_sleep_time.day}"
}

fitbit_api.log_sleep(sleep_obj)

ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
    :address        => 'smtp.gmail.com',
    :domain         => ENV["GMAIL_DOMAIN"],
    :port           => 587,
    :user_name      => ENV["GMAIL_USERNAME"],
    :password       => ENV["GMAIL_PASSWORD"],
    :authentication => :plain
}

ActionMailer::Base.mail(
    :from => ENV["GMAIL_USERNAME"], 
    :to => ENV["GMAIL_USERNAME"], 
    :content_type => "text/html",
    :subject => "Fitbit Auto Sleep for #{now.strftime "%B %d, %Y"}", 
    :body => "Fell Asleep: #{start_sleep_time.strftime "%l:%M %p"} <br/> Woke Up: #{end_sleep_time.strftime "%l:%M %p"}"
).deliver
