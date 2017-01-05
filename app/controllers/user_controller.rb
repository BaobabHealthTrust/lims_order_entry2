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
end
