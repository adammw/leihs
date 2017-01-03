class Manage::UsersController < Manage::ApplicationController

  before_action do
    not_authorized! unless group_manager?

    if params[:access_right]
      @ip_id = if params[:access_right][:inventory_pool_id] and admin?
                 params[:access_right][:inventory_pool_id]
               else
                 current_inventory_pool.id
               end
    end
  end

  before_action only: [:edit,
                       :update,
                       :destroy,
                       :set_start_screen,
                       :hand_over,
                       :take_back] do
    # @user = current_inventory_pool.users.find(params[:id])
    @user = User.find(params[:id])
  end

  before_action only: [:hand_over, :take_back] do
    unless @user.access_right_for(current_inventory_pool)
      redirect_to manage_inventory_pool_users_path,
                  flash: { error: _('No access') }
    end
  end

  private

  # NOTE overriding super controller
  def required_manager_role
    open_actions = [:hand_over]
    if not open_actions.include?(action_name.to_sym) \
      and (request.post? or not request.format.json?)
      super
    else
      require_role :group_manager, current_inventory_pool
    end
  end

  public

  ######################################################################

  def index
    @role = params[:role]
    @users = User.filter params, current_inventory_pool
    set_pagination_header @users unless params[:paginate] == 'false'
  end

  def new
    @delegation_type = true if params[:type] == 'delegation'
    @user = User.new
    @accessible_roles = get_accessible_roles_for_current_user
    @access_right = \
      @user.access_rights.new inventory_pool_id: current_inventory_pool.id,
                              role: :customer
  end

  def create
    groups = params[:user].delete(:groups) if params[:user].key?(:groups)
    if users = params[:user].delete(:users)
      delegated_user_ids = users.map { |h| h['id'] }
    end

    @user = User.new(params[:user])
    @user.login = params[:db_auth][:login] if params.key?(:db_auth)
    @user.groups = groups.map { |g| Group.find g['id'] } if groups

    begin
      User.transaction do
        @user.delegated_user_ids = delegated_user_ids if delegated_user_ids
        @user.save!

        unless @user.delegation?
          DatabaseAuthentication.create!(params[:db_auth].merge(user: @user))
          @user.update_attributes! \
            authentication_system_id: \
              AuthenticationSystem \
                .find_by_class_name(DatabaseAuthentication.name)
                .id
        end

        unless params[:access_right][:role].to_sym == :no_access
          ar = \
            @user.access_right_for(@current_inventory_pool) \
            || @user.access_rights.build(inventory_pool: @current_inventory_pool)
          ar.update_attributes! role: params[:access_right][:role]
        end

        respond_to do |format|
          format.html do
            flash[:notice] = _('User created successfully')
            redirect_to manage_inventory_pool_users_path(@current_inventory_pool)
          end
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.html do
          flash.now[:error] = e.to_s
          @accessible_roles = get_accessible_roles_for_current_user
          @delegation_type = true if params[:user].key? :delegator_user_id
          render action: :new
        end
      end
    end
  end

  def edit
    @delegation_type = @user.delegation?
    @accessible_roles = get_accessible_roles_for_current_user
    @db_auth = DatabaseAuthentication.find_by_user_id(@user.id)
    @access_right = @user.access_right_for current_inventory_pool
  end

  def update
    if params[:user]
      if params[:user].key?(:groups) and (groups = params[:user].delete(:groups))
        @user.groups = groups.map { |g| Group.find g['id'] }
      end

      delegated_user_ids = get_delegated_users_ids params
    end

    begin
      User.transaction do
        params[:user].merge!(login: params[:db_auth][:login]) if params[:db_auth]
        @user.delegated_user_ids = delegated_user_ids if delegated_user_ids
        @user.update_attributes! params[:user] if params[:user]
        if params[:db_auth]
          dbauth = DatabaseAuthentication.find_or_create_by(user_id: @user.id)
          dbauth.update_attributes! params[:db_auth].merge(user: @user)
          auth_system = \
            AuthenticationSystem.find_by_class_name(DatabaseAuthentication.name)
          @user.update_attributes! authentication_system: auth_system
        end
        @access_right = \
          AccessRight.find_or_initialize_by(user_id: @user.id,
                                            inventory_pool_id: @ip_id)
        unless @access_right.new_record? \
          and params[:access_right][:role].to_sym == :no_access
          @access_right.update_attributes! params[:access_right]
        end

        respond_to do |format|
          format.html do
            flash[:notice] = _('User details were updated successfully.')
            redirect_to manage_inventory_pool_users_path
          end
          format.json do
            render text: _('User details were updated successfully.')
          end
        end
      end
    rescue => e
      respond_to do |format|
        format.html do
          flash[:error] = e.to_s
          redirect_to :back
        end
        format.json { render text: e.to_s, status: 500 }
      end
    end
  end

  #################################################################

  def set_start_screen(path = params[:path])
    if current_user.start_screen(path)
      render nothing: true, status: :ok
    else
      render nothing: true, status: :bad_request
    end
  end

  #################################################################

  def get_accessible_roles_for_current_user
    accessible_roles = [[_('No access'), :no_access], [_('Customer'), :customer]]
    unless @delegation_type
      accessible_roles +=
        if @current_user.has_role? :admin \
          or @current_user.has_role? :inventory_manager, @current_inventory_pool
          [[_('Group manager'), :group_manager],
           [_('Lending manager'), :lending_manager],
           [_('Inventory manager'), :inventory_manager]]
        elsif @current_user.has_role? :lending_manager, @current_inventory_pool
          [[_('Group manager'), :group_manager],
           [_('Lending manager'), :lending_manager]]
        else
          []
        end
    end
    accessible_roles
  end

  def hand_over
    set_shared_visit_variables 0 do
      @contract = \
        @user
          .reservations_bundles
          .approved
          .find_by(inventory_pool_id: current_inventory_pool)
      @contract ||= \
        @user
          .reservations_bundles
          .approved
          .new(inventory_pool: current_inventory_pool) do |x|
            # simply choose the delegator user in order to
            # pass contract validation. the delegated user has to be chosen again
            # in the hand over process anyway
            x.delegated_user = @user.delegator_user if @user.delegation?
          end
      @reservations = @contract.reservations.includes([:purpose, :model])
      @models = @contract.models.where(type: :Model)
      @software = @contract.models.where(type: :Software)
      @options = @contract.options
      @items = @contract.items.items
      @licenses = @contract.items.licenses
    end
    @start_date, @end_date = \
      @grouped_lines.keys.sort.first || [Time.zone.today, Time.zone.today]
    add_visitor(@user)
  end

  def take_back
    set_shared_visit_variables 1 do
      @reservations = \
        @user
          .reservations
          .signed
          .where(inventory_pool_id: current_inventory_pool)
          .includes([:purpose, :model, :item])
      @contracts = \
        @user
          .reservations_bundles
          .signed
          .where(inventory_pool_id: current_inventory_pool)
      @models = @contracts.flat_map(&:models).uniq
      @options = @contracts.flat_map(&:options).uniq
      @items = @contracts.flat_map(&:items).uniq
    end
    @start_date = @reservations.map(&:start_date).min || Time.zone.today
    @end_date = @reservations.map(&:end_date).max || Time.zone.today
    add_visitor(@user)
  end

  private

  def set_shared_visit_variables(date_index)
    @user = User.find(params[:id]) if params[:id]
    @group_ids = @user.group_ids
    yield
    @grouped_lines = @reservations.group_by { |g| [g.start_date, g.end_date] }
    @grouped_lines.each_pair do |k, reservations|
      @grouped_lines[k] = \
        reservations.sort_by { |line| [line.model.name, line.id] }
    end
    @count_today = \
      @grouped_lines.keys.count { |range| range[date_index] == Time.zone.today }
    @count_future = \
      @grouped_lines.keys.count { |range| range[date_index] > Time.zone.today }
    @count_overdue = \
      @grouped_lines.keys.count { |range| range[date_index] < Time.zone.today }
    @grouped_lines_by_date = []
    @grouped_lines.each_pair do |range, reservations|
      @grouped_lines_by_date
        .push(date: range[date_index], grouped_lines: { range => reservations })
    end
    @grouped_lines_by_date = @grouped_lines_by_date.sort_by { |g| g[:date] }
  end

  def get_delegated_users_ids(params)
    # for complete users replacement, get only user ids without the _destroy flag
    if users = params[:user].delete(:users)
      users.select { |h| h['_destroy'] != '1' }.map { |h| h['id'] }
    end
  end

end
