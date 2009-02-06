class UsersController < ApplicationController
   layout 'application'
   before_filter :not_logged_in_required, :only => [:new, :create]
   
   before_filter :login_required, :only => [:show, :edit, :update]
   before_filter :check_super_user_role, :only => [:index, :destroy, :enable, :force_activate]

   def index
      @users = User.paginate(:page=> params[:page],
                            :per_page => 30,
                            :order => "email"
                            )
   end

  
   def show
      @user = User.find(params[:id]) || current_user
      @mymaps = @user.maps.paginate(:page => params[:page],:per_page => 8, :order => "updated_at DESC")
      @html_title = @user.login
   end

   # render new.rhtml
   def new
      @user = User.new
   end

   def create
      cookies.delete :auth_token
      @user = User.new(params[:user])
      @user.save!
      # Uncomment to have the user automatically
      # logged in after creating an account - Not Recommended
      # self.current_user = @user
      flash[:notice] = "Thanks for signing up! Please check your email to activate your account before logging in. If you dont recieve an email, then %s"
      flash[:notice_item] = ["click here to resend the email",
        resend_activation_path] 
      redirect_to login_path
   rescue ActiveRecord::RecordInvalid
      flash[:error] = "There was a problem creating your account."
      render :action => 'new'
   end

   def edit
      @user = current_user
      @html_title = "Edit User Profile - " + @user.login
   end

   def update
      @user = User.find(current_user)
      if @user.update_attributes(params[:user])
         flash[:notice] = "User updated"
         redirect_to :action => 'show', :id => current_user
      else
         render :action => 'edit'
      end
   end

   def destroy
      @user = User.find(params[:id])
      if @user.update_attribute(:enabled, false)
         flash[:notice] = "User disabled"
      else
         flash[:error] = "There was a problem disabling this user."
      end
      redirect_to :action => 'index'
   end

   def enable
      @user = User.find(params[:id])
      if @user.update_attribute(:enabled, true)
         flash[:notice] = "User enabled"
      else
         flash[:error] = "There was a problem enabling this user."
      end
      redirect_to :action => 'index'
   end

   def activate
      @user = User.find_by_activation_code(params[:id])
      if @user and @user.activate
         self.current_user = @user
         redirect_back_or_default(:controller => '/user_account', :action => 'index')
         flash[:notice] = "Your account has been activated."
      end
      redirect_to :action => 'index'
   end

  #called from admin console thingy
   def force_activate
     @user = User.find(params[:id])
     if !@user.active?
       @user.force_activate!
       if @user.active? 
         flash[:notice] = "User activated"
       else
         flash[:error] = "There was a problem activating this user."
       end
     else
       flash[:notice] = "User already active"
     end
     redirect_to :action => 'index'
   end
   
   def resend_activation
    return unless request.post?

    @user = User.find_by_email(params[:email])
    if @user && !@user.active?
      flash[:notice] = "Activation email has been resent, check your email."
      UserMailer.deliver_signup_notification(@user)
      redirect_to login_path and return
    else
      flash[:notice] = "Activation email was not sent, either because the email was not the same as you gave when you signed up, or you have already been activated!"
      
    end
   end

end
