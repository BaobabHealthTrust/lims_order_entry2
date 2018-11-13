class PatientController < ApplicationController
  $tra_number = 0
  $couch_id = 0
  $p_national_id = ""
  $p_name = ""
  $p_gender = ""
  $p_dob = ""
  def barcode
    if session[:return_path].present?
      path = session[:return_path] #+ "?tracking_number=#{$tra_number}"
      path = path.split("?")[0].to_s + "?tracking_number=#{$tra_number}" + "&couch_id=#{$couch_id}"  "&date_created=#{$tra_number}"  
      reset_session
      redirect_to path  and return
    end

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


  def enter_test_result
    configs = YAML.load_file "#{Rails.root}/config/application.yml"
    bart2_address = configs['bart2_address'] + "/people/remote_demographics"
    details = params[:tracking_number].split("_")
    tracking_number = details[0]
    identifier = details[1]
    @data = JSON.parse(RestClient.post(bart2_address, :content_type => "application/json", :person => {"value" => identifier}))['person'] rescue nil
 
    redirect_to "/patient/barcode" and return if @data.blank?
    @national_id = @data['patient']['identifiers']['National id']
    @name = @data['names']
    @address = @data['addresses']
    @gender = @data['gender']
    @dob = @data['birthdate'].to_date rescue nil
    @age = age(@dob)

  end
  
  def show
    configs = YAML.load_file "#{Rails.root}/config/application.yml"
    #bart2_address = configs['bart2_address'] + "/people/remote_demographics"
    #@direct_result_entry = configs['direct_result_entry']
    #@data = JSON.parse(RestClient.post(bart2_address, :content_type => "application/json", :person => {"value" => params["identifier"]}))['person'] rescue nil
    #redirect_to "/patient/barcode" and return if @data.blank?
    @national_id =  $p_national_id #"@data['patient']['identifiers']['National id']
    @name = $p_name #@data['names']
    @address =  $p_addres #@data['addresses']
    @gender = $p_gender  #@data['gender']
    @dob = $p_dob  #@data['birthdate'].to_date rescue nil
    @age = age(@dob)

    if configs['nlims_controller'] == true
      token = File.read("#{Rails.root}/tmp/token")
      check_token_url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/check_token_validity"
      headers = {
        content_type: 'application/json',
        token: token
      }
      res = JSON.parse(RestClient.get(check_token_url, headers ))
      if res['error'] == false
                @nlims_controller = true
                url = "#{configs['nlims_controller_ip']}/api/v1/query_order_by_npid/#{@national_id}"
                res =  JSON.parse(RestClient.get(url,headers))
                @results = {}
                tracking_number = ""
                test_results = {}                
                if res['error'] == false
                  @tests = res['data']['orders']
                  @tests.each do |t|           
                    tracking_number = t['tracking_number']
                    url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/query_results_by_tracking_number/#{tracking_number}"
                    res =  JSON.parse(RestClient.get(url,headers))
                    if res['error'] == true
                    else            
                      @results[tracking_number] = res['data']['results']
                    end
                  end      
                else
                  puts res['message']
                end
      else
        if res['message'] == 'token expired'
          re_auth_url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/re_authenticate/#{configs['nlims_custome_username']}/#{configs['nlims_custome_password']}"
          res = JSON.parse(RestClient.get(re_auth_url, :content_type => 'application/json'))
          if res['error'] == false
              token = res['data']['token']
              File.open("#{Rails.root}/tmp/token", "w") { |f|
                f.write(token)
              }
                @nlims_controller = true
                headers = {
                  content_type: 'application/json',
                  token: token
                }
                url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/query_order_by_npid/#{@national_id}"
                res =  JSON.parse(RestClient.get(url,headers))
                @results = {}
                tracking_number = ""
                test_results = {}                
                if res['error'] == false
                  @tests = res['data']['orders']
                  @tests.each do |t|           
                    tracking_number = t['tracking_number']
                    url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/query_results_by_tracking_number/#{tracking_number}"
                    res =  JSON.parse(RestClient.get(url,headers))
                    if res['error'] == true
                    else            
                      @results[tracking_number] = res['data']['results']
                    end
                  end      
                else
                    puts res['message']
                end
          else
            puts  res['message']
          end

        end
      end

    else

      startkey = "#{@national_id.strip}_10000000000000"
      endkey = "#{@national_id.strip}_#{Time.now.strftime('%Y%m%d%H%M%S')}"

      @tests = []
      Order.by_national_id_and_datetime.startkey([startkey]).endkey([endkey]).each {|order|
        @tests << {"tracking_number" => order['_id'],
                   "sample_type" => order['sample_type'],
                   "test_types" => order['test_types'],
                   "date_ordered" => order['date_time'].to_datetime.strftime("%d-%b-%Y   &nbsp;&nbsp;&nbsp; %H:%M"),
                   "time_ordered" => order['date_time'].to_datetime.strftime("%H:%M"),
                   "results" => (order['results'].collect{|test, trails|key = trails.keys.last; {test => trails[key]}} rescue [])
        }
      }

      @tests =  @tests.reverse
    end


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
     $p_national_id = params[:identifier] #data['patient']['identifiers']['National id']
     $p_name = params[:name]
     $p_gender = params[:gender]
     $p_dob = params[:dob] 
     $p_addres = params[:address]
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
    #data = JSON.parse(RestClient.post(bart2_address, :content_type => "application/json", :person => {"value" => params["identifier"]}))['person'] rescue nil
   
    #redirect_to "/patient/barcode" and return if data.blank?    
    national_id =   $p_national_id #data['patient']['identifiers']['National id']
    name =          $p_name.split("-")
    gender =        $p_gender
    dob =           $p_dob #data['birthdate'].to_date.strftime("%Y-%m-%d") rescue nil
    attributes =    $p_addres  #data['attributes']
    
    art_start_date = '00' #RestClient.post(art_start_date_url,:identifier => national_id.to_s,:content_type =>'application/text')
  
    json = { :return_path => "http://#{request.host}:#{request.port}",
             :district => configs['district'],
             :health_facility_name => configs['facility_name'],
             :first_name=> name[0],
             :last_name=> name[1],
             :middle_name=> name[1],
             :date_of_birth=> dob,
             :gender=> gender,
             :national_patient_id=> national_id,
             :phone_number=> "",
             :reason_for_test=> (test_types.include?("EID") ? 'HIV Exposed Infant' : 'Routine'),
             :sample_collector_last_name=> (session[:user].strip.split(/\s+/)[1] rescue nil),
             :sample_collector_first_name=> (session[:user].strip.split(/\s+/)[0] rescue nil),
             :sample_collector_phone_number=> '',
             :sample_collector_id=> '',
             :sample_order_location=> 'OPD 2',
             :sample_type=> specimen_type,
             :date_sample_drawn=> Date.today.strftime("%a %b %d %Y"),
             :tests=> test_types,
             :sample_priority=> params[:priority] || 'Routine',
             :target_lab=> params[:target_lab],
             :tracking_number => "",
             :art_start_date => (art_start_date rescue nil),
             :date_dispatched => "",
             :date_received => Time.now,
             :requesting_clinician => 'join doe',
             :return_json => 'true'
    }
   
    if configs['nlims_controller'] == true
        json = {
                :district => configs['district'],
                :health_facility_name => configs['facility_name'],
                :first_name=> name[0],
                :last_name=>  name[1],
                :middle_name=> name[1],
                :date_of_birth=> dob,
                :gender=> gender,
                :national_patient_id=>  national_id,
                :phone_number=> "",
                :reason_for_test=> (test_types.include?("EID") ? 'HIV Exposed Infant' : 'Routine'),
                :who_order_test_last_name=> (session[:user].strip.split(/\s+/)[1] rescue nil),
                :who_order_test_first_name=> (session[:user].strip.split(/\s+/)[0] rescue nil),
                :who_order_test_phone_number=> '',
                :who_order_test_id=> '',
                :order_location=> 'CWC',
                :sample_type=> specimen_type,
                :date_sample_drawn=> Date.today.strftime("%Y%m%d%H%M%S"),
                :tests=> test_types,
                :sample_priority=> params[:priority] || 'Routine',
                :target_lab=> params[:target_lab],            
                :art_start_date => (art_start_date rescue nil),            
                :date_received => Date.today.strftime("%Y%m%d%H%M%S"),
                :requesting_clinician => ""         
        }

      token = File.read("#{Rails.root}/tmp/token")
      check_token_url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/check_token_validity"
      headers = {
        content_type: 'application/json',
        token: token
      }
      res = JSON.parse(RestClient.get(check_token_url, headers))
    
      if res['error'] == false
          url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/create_order"
          headers = {
            token: token,
            content_type: 'application/json',
          }
          paramz = JSON.parse(RestClient.post(url, json, headers))
      
          if paramz['error'] == true
              msg = paramz['message']
              redirect_to "/patient/new_lab_results?identifier=#{national_id}", flash: {error: 'national_lims:  ' + msg}           
          else
            tracking_number = paramz['data']['tracking_number']           
            $tra_number = tracking_number       
            $couch_id =  paramz['data']['couch_id'] 
            print_url = "/patient/print_tracking_number?tracking_number=#{tracking_number}"
            print_and_redirect(print_url, "/patient/show?identifier=#{national_id}")
          end
      else
          
        if res['message'] == 'token expired'
          re_auth_url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/re_authenticate/#{configs['nlims_custome_username']}/#{configs['nlims_custome_password']}"
          res = JSON.parse(RestClient.get(re_auth_url, :content_type => 'application/json'))
          
          if res['error'] === false
            token = res['data']['token']
            File.open("#{Rails.root}/tmp/token", "w") { |f|
              f.write(token)
            }
            headers = {
              token: token,
              content_type: 'application/json',
            }
              url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/create_order"
              paramz = JSON.parse(RestClient.post(url, json, headers))

              if paramz['error'] == true
                msg = paramz['message']
                redirect_to "/patient/new_lab_results?identifier=#{national_id}", flash: {error: 'national_lims:  ' + msg}           
              else
                tracking_number = paramz['data']['tracking_number']                
                print_url = "/patient/print_tracking_number?tracking_number=#{tracking_number}"
                print_and_redirect(print_url, "/patient/show?identifier=#{national_id}")

              end
          else
              msg = res['message']
              redirect_to "/patient/new_lab_results?identifier=#{national_id}", flash: {error: 'national_lims:  ' + msg}
          end
        else
            msg = res['message']
            redirect_to "/patient/new_lab_results?identifier=#{national_id}", flash: {error: 'national_lims:  ' + msg}
        end
      end
    else

      url = "#{configs['national-repo-node']}/create_hl7_order"
      paramz = JSON.parse(RestClient.post(url, json))

      print_url = "/patient/print_tracking_number?tracking_number=#{paramz['tracking_number']}"
      print_and_redirect(print_url, "/patient/show?identifier=#{national_id}")
    end


  end


  def age(birthdate , today=Date.today)
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0) rescue "Unknown"
    return patient_age
  end

  def print_tracking_number
    require 'auto12epl'
    configs = YAML.load_file "#{Rails.root}/config/application.yml"

    if configs['nlims_controller'] == true
      token = File.read("#{Rails.root}/tmp/token")
      check_token_url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/check_token_validity"
      headers = {
        content_type: 'application/json',
        token: token
      }
      res = JSON.parse(RestClient.get(check_token_url, headers))

      if res['error'] == false
            url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/query_order_by_tracking_number/#{params[:tracking_number]}"
            headers = {
              content_type: 'application/json',
              token: token
            }
            res = JSON.parse(RestClient.get(url, headers))
            tname = []
           
            if res['error'] == false
                patient = res['data']['other']['patient']
                other = res['data']['other']
                tests = res['data']['tests']
                tests.each do |key, value|
                  tname.push(key)
                end
                tnam = tname.join(",")        
                middle_initial = patient['middle_name'].strip.scan(/\s\w+\s/).first.strip[0 .. 2] rescue ""
                dob = patient['dob'].to_date.strftime("%d-%b-%Y") rescue '-'
                age = age(dob, other['date_created']) rescue "-"
                gender = patient['gender']
                col_datetime = other['date_created'].to_datetime.strftime("%d-%b-%Y %H:%M")
                col_by = 'gibo' #other['collector']['name']
                stat_el = other['priority'].downcase.to_s == "stat" ? "STAT" : nil
                formatted_acc_num = params["tracking_number"]
                numerical_acc_num = params['tracking_number']
                pat_first_name = patient['name'].split(" ")[0]
                pat_last_name = patient['name'].split(" ")[1]             

                auto = Auto12Epl.new
                s =  auto.generate_epl(pat_first_name.to_s, pat_last_name.to_s, middle_initial.to_s, patient['id'], dob, age.to_s,
                                       gender.to_s, col_datetime, col_by.to_s, tnam.to_s,
                                       stat_el, formatted_acc_num.to_s, numerical_acc_num)

                send_data(s,
                          :type=>"application/label; charset=utf-8",
                          :stream=> false,
                          :filename=>"#{params['tracking_number']}-#{rand(10000)}.lbl",
                          :disposition => "inline"  )



            else
              msg = res['message']
              redirect_to "/patient/new_lab_results?identifier=#{national_id}", flash: {error: 'national_lims:  ' + msg}
            end
      else
        if res['message'] == 'token expired'
          re_auth_url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/re_authenticate/#{configs['nlims_custome_username']}/#{configs['nlims_custome_password']}"
          res = RestClient.get(re_auth_url, :content_type => 'application/json')
          if res['error'] == false
              token = res['data']['token']
              File.open("#{Rails.root}/tmp/token", "w") { |f|
                f.write(token)
              }
                    url = "#{configs['nlims_controller_ip']}/api/#{configs['nlims_api_version']}/query_order_by_tracking_number/#{params[:tracking_number]}/#{token}"
                    res = JSON.parse(RestClient.get(url))
                    tname = []

                    if res['error'] == false


                      patient = res['data']['other']['patient']
                      other = res['data']['other']
                      tests = res['data']['tests']

                        tests.each do |key, value|
                          tname.push(key)
                        end
                        tnam = tname.join(",")

                 
                       middle_initial = patient['middle_name'].strip.scan(/\s\w+\s/).first.strip[0 .. 2] rescue ""
                        dob = patient['dob'].to_date.strftime("%d-%b-%Y") rescue '-'

                        age = age(dob, other['date_created']) rescue "-"

                        gender = patient['gender']
                        col_datetime = other['date_created'].to_datetime.strftime("%d-%b-%Y %H:%M")
                        col_by = other['collector']['name']
                        stat_el = other['priority'].downcase.to_s == "stat" ? "STAT" : nil
                        formatted_acc_num = params["tracking_number"]
                        numerical_acc_num = params['tracking_number']
                        pat_first_name = patient['name'].split(" ")[0]
                        pat_last_name = patient['name'].split(" ")[1]
                      

                        auto = Auto12Epl.new
                        s =  auto.generate_epl(pat_first_name.to_s, pat_last_name.to_s, middle_initial.to_s, patient['id'], dob, age.to_s,
                                               gender.to_s, col_datetime, col_by.to_s, tnam.to_s,
                                               stat_el, formatted_acc_num.to_s, numerical_acc_num)

                        send_data(s,
                                  :type=>"application/label; charset=utf-8",
                                  :stream=> false,
                                  :filename=>"#{params['tracking_number']}-#{rand(10000)}.lbl",
                                  :disposition => "inline"  )



                    else
                      msg = res['message']
                      redirect_to "/patient/new_lab_results?identifier=#{national_id}", flash: {error: 'Print Failed! national_lims:  ' + msg}
                    end
          else
            msg = res['message']
            redirect_to "/patient/new_lab_results?identifier=#{national_id}", flash: {error: 'national_lims:  ' + msg}
          end

        end

      end

    else

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

end
