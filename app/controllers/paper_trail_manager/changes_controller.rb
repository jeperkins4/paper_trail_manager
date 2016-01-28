# Allow the parent class of ChangesController to be configured in the host app
PaperTrailManager::ChangesController = Class.new(PaperTrailManager.base_controller.constantize)

class PaperTrailManager::ChangesController
  before_filter :authenticate_user!
  # Default number of changes to list on a pagenated index page.
  PER_PAGE = 50

  helper PaperTrailManager.route_helpers if PaperTrailManager.route_helpers
  helper PaperTrailManager::ChangesHelper
  layout PaperTrailManager.layout if PaperTrailManager.layout

  # List changes
  def index
    unless change_index_allowed?
      flash[:error] = "You do not have permission to list changes."
      return(redirect_to root_url)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.atom # index.atom.builder
      #format.json { render :json => @versions }
      format.json { render json: PaperTrailManager::ChangesDatatable.new(view_context) }
    end
  end

  # Show a change
  def show
    begin
      @version = PaperTrail::Version.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "No such version."
      return(redirect_to :action => :index)
    end

    unless change_show_allowed?(@version)
      flash[:error] = "You do not have permission to show that change."
      return(redirect_to :action => :index)
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @version }
    end
  end

  # Rollback a change
  def update
    begin
      @version = PaperTrail::Version.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "No such version."
      return(redirect_to(changes_path))
    end

    unless change_revert_allowed?(@version)
      flash[:error] = "You do not have permission to revert this change."
      return(redirect_to changes_path)
    end

    if @version.event == "create"
      @record = @version.item_type.constantize.find(@version.item_id)
      @result = @record.destroy
    else
      @record = @version.reify
      @result = @record.save
    end

    if @result
      if @version.event == "create"
        flash[:notice] = "Rolled back newly-created record by destroying it."
        redirect_to changes_path
      else
        flash[:notice] = "Rolled back changes to this record."
        redirect_to change_item_url(@version)
      end
    else
      flash[:error] = "Couldn't rollback. Sorry."
      redirect_to changes_path
    end
  end

protected

  # Return the URL for the item represented by the +version+, e.g. a Company record instance referenced by a version.
  def change_item_url(version)
    version_type = version.item_type.underscore.split('/').last
    return send("#{version_type}_url", version.item_id)
  rescue NoMethodError
    return nil
  end
  helper_method :change_item_url

  # Allow index?
  def change_index_allowed?
    return PaperTrailManager.allow_index?(self)
  end
  helper_method :change_index_allowed?

  # Allow show?
  def change_show_allowed?(version)
    return PaperTrailManager.allow_show?(self, version)
  end
  helper_method :change_show_allowed?

  # Allow revert?
  def change_revert_allowed?(version)
    return PaperTrailManager.allow_revert?(self, version)
  end
  helper_method :change_revert_allowed?
end
