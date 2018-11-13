class UserController < ApplicationController

  def logout
    reset_session
    redirect_to "/user/login"
  end

  def login

  end

  def do_login
    configs = YAML.load_file "#{Rails.root}/config/application.yml"
    bart2_address = configs['bart2_address'] + "/single_sign_on/get_token"

    user = JSON.parse(RestClient.post(bart2_address,
                                      {"login" => params[:user][:username],
                                       "password" => params[:user][:password],
                                      "location" => params[:location]})) rescue nil


    if user.blank?
      flash[:error] = "Invalid User"
    elsif (user["auth_token"].blank? rescue true)
      flash[:error] = "Invalid User"
    elsif (user["location"].blank? rescue true)
      flash[:error] = "Could not find location identified by #{params[:location]}"
    end

    redirect_to "/user/logout" and return if user.blank? || user['auth_token'].blank? || user['location'].blank?

    session[:token] = user["auth_token"]
    session[:user] = user["name"]
    session[:location] = user["location"]

    redirect_to "/patient/barcode"
  end

  def ext
    if params['username'] && params['name'] && params['location'] && params['tk']
      session[:user] = params["name"]
      session[:location] = params["location"]
      session[:return_path] = params["return_path"]
      session['token'] = params['tk']   
      p_gender =  params[:gender]
      p_name = params[:p_name]
      p_dob = params[:dob]
      p_address = params[:address]
  
      case params['intent']
        when 'new_order'
          redirect_to "/patient/new_lab_results?identifier=#{params['identifier']}&gender=#{p_gender}&name=#{p_name}&dob=#{p_dob}&address=#{p_address}" and return
        when 'lab_trail'
          redirect_to "/patient/show?identifier=#{params['identifier']}" and return
      end

      redirect_to params['return_path']
     else
      session[:token]  = "hello"
      redirect_to "/undispatched_samples" and return
    end
  end
end
