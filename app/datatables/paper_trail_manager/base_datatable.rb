class PaperTrailManager::BaseDatatable
  delegate :content_tag, :current_user, :params, :links, :html_safe, :h, :l, :localize, :t, :status_tag, :link_to_if, :button_to,
    :can?, :link_to, :class, :session, to: :@view

  attr_accessor :exceptions

  def initialize(view)
    @view = view
  end

  def json_builder(total, display, data)
    { sEcho: params[:sEcho].to_i, iTotalRecords: total, iTotalDisplayRecords: display, aaData: data }
  end

  def date(obj)
    obj.nil? ? nil : l(obj, format: :long)
  end

  def fetch_results(table_name)
    results = table_name.order(order_by(columns))
    results = results.where(where_clause) if params[:search] && params[:search]['value'].present?
    results.page(page_count).per(per_page)
  end

  def year_filter
    d = Date.today
    year = d.year
    if params.key?(:search) && params[:search].key?(:value)
      year = params[:search][:value] unless params[:search][:value].blank?
    end
    if year.size == 4
      d = Date.new(year.to_i+1,1,1)
    end
    return d
  end

  def links(obj)
    html = []
    edit_link = obj.is_a?(Array) ? [:edit] + obj : [:edit] << obj
    html << link_to(t('edit',to: nil).html_safe, edit_link, :class => 'btn btn-default btn-xs')
    html << link_to(t('destroy').html_safe, obj, :method => :delete, :data => { :confirm => 'Are you sure?' }, :class => 'btn btn-xs btn-danger')
    content_tag('div',html.join(' ').html_safe,:class => 'buttons') if can?(:manage, obj.class)
  end
private
  def page_count
    params[:start].to_i/per_page + 1
  end

  def per_page
    params[:length].to_i > 0 ? params[:length].to_i : 10
  end

  def where_clause
    return if params[:search][:value].blank?
    like_clause(search: params[:search][:value], space: '_', columns: columns)
  end

  def order_by(columns)
    clause = ''
    return columns[0] if params[:order].nil?
    params[:order].each do |item|
      clause += "#{columns[item[1][:column].to_i]} #{item[1][:dir]}, "
    end
    clause.strip.chop
  end

  def like_clause(search: '', space: ' ', columns: [])
    return if columns.blank?
    columns.compact.delete_if{|c|exceptions.include?(c)}.map { |column| "#{column} like '%#{search.sub ' ', space}%'" }.join(' or ')
  end
end
