class PatientController < ApplicationController
  def barcode
    render :layout => false
  end

  def captureDispatcher
    @samples = Order.by_sample.reduce.group_level(1)
    @specimen = []
    count = 0
      @samples.rows.each do |row|
        @specimen[count]  = row.key
        count = count + 1 
      end
  end

  def load_orders
     #getting orders that have Drawn status + within that facility + for the selected sample
     configs = YAML.load_file "#{Rails.root}/config/application.yml"
     facility_name = configs['facility_name']
     @data = []
     count =0 
     @data_got = nil
     patient_name =""
     patient_id = ""
     order_keys = []

     da = Order.by_sample_type_order.key(params[:selected_sample])
     
     da.rows.each {|ro|
            order_keys = ro.value.keys
            next if order_keys.include?('who_dispatched')
            @data[count] = ro.value['_id'] + "("  + ro.value['patient']['first_name'] +"_"+ ro.value['patient']['last_name']+ ")" rescue nil
            count = count + 1               
     }



     render :text => @data.collect{|name| "<li>#{name}"}.join("</li>")+"</li>"
  end


  def postDispatcher

     configs = YAML.load_file "#{Rails.root}/config/application.yml"   
     un_orders =  params[:undispatched_orders] rescue nil
     track_number = ""
     id = params[:id]
     f_name = params[:f_name]
     l_name = params[:l_name]
     phone = params[:phone]
    
     date_dis = params[:date_dispatched]    
     date_dis = params[:date_dispatched]    

      un_orders.each do |r|
        track_number = r.split('(')

          son = { :return_path => "http://#{request.host}:#{request.port}",
             :_id => track_number[0],
             :date_dispatched => date_dis,
             :who_dispatched => {
                              :id_number => id,
                              :first_name => f_name,
                              :last_name => l_name,
                              :phone_number => phone
                              },
             :return_json => 'true'
               }
         url = "#{configs['central_repo']}/pass_json/"
         RestClient.post(url,son.to_json,:content_type =>'application/json')
      end   
         redirect_to action: 'barcode'
  end

  def show

    configs = YAML.load_file "#{Rails.root}/config/application.yml"
    bart2_address = configs['bart2_address'] + "/people/remote_demographics"

    @data = JSON.parse(RestClient.post(bart2_address, :content_type => "application/json", :person => {"value" => params["identifier"]}))['person'] rescue nil

    redirect_to "/patient/barcode" and return if @data.blank?

    @national_id = @data['patient']['identifiers']['National id']
    @name = @data['names']
    @address = @data['addresses']
    @gender = @data['gender']
    @dob = "#{@data['birth_day']}/#{@data['birth_month']}/#{@data['birth_year']}".to_date rescue nil
    @age = age(@dob)

    startkey = "#{@national_id.strip}_10000000000000"
    endkey = "#{@national_id.strip}_#{Time.now.strftime('%Y%m%d%H%M%S')}"

    @tests = []
    Order.by_national_id_and_datetime.startkey([startkey]).endkey([endkey]).each {|order|
      @tests << {"tracking_number" => order['_id'],
                 "sample_type" => order['sample_type'],
                 "test_types" => order['test_types'],
                 "date_ordered" => order['date_time'].to_datetime.strftime("%d/%b/%Y"),
                 "time_ordered" => order['date_time'].to_datetime.strftime("%H:%M")
      }
    }

    @tests =  @tests.reverse

  end

  def confirm
      configs = YAML.load_file "#{Rails.root}/config/application.yml"
      bart2_address = configs['bart2_address'] + "/people/remote_demographics"

      @data = JSON.parse(RestClient.post(bart2_address, :content_type => "application/json", :person => {"value" => params["identifier"]}))['person'] rescue nil

      redirect_to "/patient/barcode" and return if @data.blank?

      @national_id = @data['patient']['identifiers']['National id']
      @name = @data['names']
      @address = @data['addresses']
      @gender = @data['gender']
      @dob = "#{@data['birth_day']}/#{@data['birth_month']}/#{@data['birth_year']}".to_date rescue nil
      @attributes = @data['attributes']

      startkey = "#{@national_id.strip}_10000000000000"
      endkey = "#{@national_id.strip}_#{Time.now.strftime('%Y%m%d%H%M%S')}"

      @tests = []
      Order.by_national_id_and_datetime.startkey([startkey]).endkey([endkey]).each {|order|
        @tests << {"sample_type" => order['sample_type'], "test_types" => order['test_types'], "date_ordered" => order['date_time'].to_date.strftime("%d/%b/%Y")}
      }

     @tests =  @tests.reverse[0 .. 10]
     render :layout => false
  end

  def new_lab_results
     catalog = JSON.parse(File.read("#{Rails.root}/config/test_catalog.json"))
     @specimen_types = catalog.keys.sort
  end

  def test_types

    catalog = JSON.parse(File.read("#{Rails.root}/config/test_catalog.json"))
    test_types = catalog[params['specimen_type']]

    #test_types.delete_if{|t|
    #  !t.match(/#{params[:search_string]}/i)
    #}

    render :text => "<li>" + test_types.uniq.map{|n| n } .join("</li><li>") + "</li>"

  end

  def new_order
    specimen_type = CGI.unescapeHTML(params[:specimen_type])
	
    test_types =  params[:test_types]


    configs = YAML.load_file "#{Rails.root}/config/application.yml"
    bart2_address = configs['bart2_address'] + "/people/remote_demographics"
    art_start_date_url = configs['bart2_address'] + "/render_date_enrolled_in_art"
    data = JSON.parse(RestClient.post(bart2_address, :content_type => "application/json", :person => {"value" => params["identifier"]}))['person'] rescue nil

    redirect_to "/patient/barcode" and return if data.blank?

    national_id = data['patient']['identifiers']['National id']
    name = data['names']
    gender = data['gender']
    dob = "#{data['birth_day']}/#{data['birth_month']}/#{data['birth_year']}".to_date.strftime("%a %b %d %Y") rescue nil
    attributes = data['attributes']
   
    art_start_date = RestClient.post(art_start_date_url,:identifier => national_id.to_s,:content_type =>'application/text')

    json = { :return_path => "http://#{request.host}:#{request.port}",
             :district => configs['district'],
             :health_facility_name => configs['facility_name'],
             :first_name=> name['given_name'],
             :last_name=> name['family_name'],
             :middle_name=> name['family_name2'],
             :date_of_birth=> dob,
             :gender=> gender,
             :national_patient_id=> national_id,
             :phone_number=> (attributes['cell_phone_number'] ||
                 attributes['home_phone_number'] ||
                 attributes['office_phone_number']),
             :reason_for_test=> 'Routine',
             :sample_collector_last_name=> (session[:user].strip.split(/\s+/)[1] rescue nil),
             :sample_collector_first_name=> (session[:user].strip.split(/\s+/)[0] rescue nil),
             :sample_collector_phone_number=> '',
             :sample_collector_id=> '',
             :sample_order_location=> (configs['facility_name'] || session[:location]),
             :sample_type=> specimen_type,
             :date_sample_drawn=> Date.today.strftime("%a %b %d %Y"),
             :tests=> test_types,
             :sample_priority=> params[:priority] || 'Routine',
             :target_lab=> configs['receiving_facility'],
             :tracking_number => "",
             :art_start_date => (art_start_date rescue nil),
             :date_dispatched => "",
             :date_received => Time.now,
             :return_json => 'true'
    }

    url = "#{configs['national-repo-node']}/create_hl7_order"

    paramz = JSON.parse(RestClient.post(url, json))
    print_url = "/patient/print_tracking_number?tracking_number=#{paramz['tracking_number']}"
    print_and_redirect(print_url, "/patient/show?identifier=#{national_id}")
  end


  def age(birthdate , today=Date.today)
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0) rescue "Unknown"
    return patient_age
  end

  def print_tracking_number
    require 'auto12epl'

    order = Order.find(params["tracking_number"])
    patient = order['patient']
    tname = order['test_types'].join(', ')

    middle_initial = patient['middle_name'].strip.scan(/\s\w+\s/).first.strip[0 .. 2] rescue ""
    dob = patient['date_of_birth'].to_date.strftime("%d-%b-%Y") rescue '-'

    age = age(dob, order['date_time']) rescue "-"

    gender = patient['gender']
    col_datetime = order['date_time'].to_datetime.strftime("%d-%b-%Y %H:%M")
    col_by = (order['who_order_test']['first_name'] + ' ' + order['who_order_test']['last_name']).strip
    stat_el = order['priority'].downcase.to_s == "stat" ? "STAT" : nil
    formatted_acc_num = params["tracking_number"]
    numerical_acc_num = params['tracking_number']

    auto = Auto12Epl.new
    s =  auto.generate_epl(patient['last_name'].to_s, patient['first_name'].to_s, middle_initial.to_s, patient['national_patient_id'], dob, age.to_s,
                           gender.to_s, col_datetime, col_by.to_s, tname.to_s,
                           stat_el, formatted_acc_num.to_s, numerical_acc_num)

    send_data(s,
              :type=>"application/label; charset=utf-8",
              :stream=> false,
              :filename=>"#{params['tracking_number']}-#{rand(10000)}.lbl",
              :disposition => "inline"
    )
  end

end
