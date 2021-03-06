require 'net/http'
require 'net/https'
require 'uri'
require "rexml/document"

module Googlecalendar
  # A ruby class to wrap calls to the Google Data API
  # 
  # More informations
  # 
  # Google calendar API: http://code.google.com/apis/calendar/developers_guide_protocol.html
  class GData
    attr_accessor :google_url
    
    def initialize(google='www.google.com')
      @calendars = []
      @google_url = google
    end

    #Log into google data, this method needs to be call once before using other methods of the class
    #* Email   The user's email address.
    #* Passwd  The user's password.
    #* source  Identifies your client application. Should take the form companyName-applicationName-versionID
    #*Warning* Replace the default value with something like: 
    #+companyName-applicationName-versionID+ 
    def login(email, pwd, source='googlecalendar.rubyforge.org-googlecalendar-default')
      # service   The string cl, which is the service name for Google Calendar.
      @user_id = email
      response = Net::HTTPS.post_form(URI.parse("https://#{@google_url}/accounts/ClientLogin"),
          { 'Email' => email, 
            'Passwd' => pwd, 
            'source' => source, 
            'accountType' => 'HOSTED_OR_GOOGLE', 
            'service' => 'cl'})
      response.error! unless response.kind_of? Net::HTTPSuccess
      @token = response.body.split(/=/).last
      @headers = {
         'Authorization' => "GoogleLogin auth=#{@token}",
         'Content-Type'  => 'application/atom+xml'
       }
       return @token
    end # login
  
    #'event' param is a hash containing 
    #* :title
    #* :content
    #* :author
    #* :email
    #* :where
    #* :startTime '2007-06-06T15:00:00.000Z'
    #* :endTime '2007-06-06T17:00:00.000Z'
    # 
    # Use add_reminder(event, reminderMinutes, reminderMethod) method to add reminders
    def new_event(event={},calendar = nil)
      new_event = template(event)
      post_event(new_event, calendar)
    end
    
    def post_event(xml, calendar = nil)
      #Get calendar url    
      calendar_url  = if calendar
	'/calendar/feeds/'+calendar+'/private/full'
      else
        # We will use user'default calendar in this case
        '/calendar/feeds/default/private/full'
      end
      
      http = Net::HTTP.new(@google_url, 80)
      response, data = http.post(calendar_url, xml, @headers)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        redirect_response, redirect_data = http.post(response['location'], xml, @headers)
        case response
        when Net::HTTPSuccess, Net::HTTPRedirection
          return redirect_response
        else
          response.error!
        end
      else
        response.error!
      end
    end # post_event
  
    # The atom event template to submit a new event
    def template(event={})
  content = <<EOF
<?xml version="1.0"?>
<entry xmlns='http://www.w3.org/2005/Atom'
    xmlns:gd='http://schemas.google.com/g/2005'>
  <category scheme='http://schemas.google.com/g/2005#kind'
    term='http://schemas.google.com/g/2005#event'></category>
  <title type='text'>#{event[:title]}</title>
  <content type='text'>#{event[:content]}</content>
  <author>
    <name>#{event[:author]}</name>
    <email>#{event[:email]}</email>
  </author>
  <gd:transparency
    value='http://schemas.google.com/g/2005#event.opaque'>
  </gd:transparency>
  <gd:eventStatus
    value='http://schemas.google.com/g/2005#event.confirmed'>
  </gd:eventStatus>
  <gd:where valueString='#{event[:where]}'></gd:where>
  <gd:when startTime='#{event[:startTime]}' endTime='#{event[:endTime]}'>
    #{event[:reminders]}
  </gd:when>
</entry>
EOF
    end # template
  end # GData class  
end # module Googlecalendar
