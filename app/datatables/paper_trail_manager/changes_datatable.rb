class PaperTrailManager::ChangesDatatable < PaperTrailManager::BaseDatatable
  delegate :current_user, :change_path, :admin_user_path, :user_path, :change_show_allowed?, :changes_for, :change_title_for, :change_item_types, :change_item_link, :version_reify, :text_or_nil, to: :@view

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: PaperTrail::Version.count,
      iTotalDisplayRecords: versions.total_count,
      aaData: data
    }
  end

private
  def data
    versions.map do |version|
      [
        change_time(version),
        #link_to(version.whodunnit, version),
        version.item_type,
        version.event,
        version.whodunnit,
        version.created_at,
        change_details(version),
        rollback(version)
      ]
    end
  end

  def versions
    @versions || fetch_versions
  end

  def fetch_versions
    versions = PaperTrail::Version.order(order_by(columns))

    if params.key?(:columns)
      if params[:columns]['1'].present? && params[:columns]['1'][:search][:value].present?
        q = params[:columns]['1'][:search][:value].split("|")
        #sticky(:dt_candidates_supplier, q)
        versions = versions.where(item_type: q.map(&:singularize)) unless q.blank?
      #else
        #sticky(:dt_candidates_supplier, nil)
      end
      if params[:columns]['2'].present? && params[:columns]['2'][:search][:value].present?
        q = params[:columns]['2'][:search][:value].split("|")
        #sticky(:dt_candidates_supplier, q)
        versions = versions.where(event: q) unless q.blank?
      #else
        #sticky(:dt_candidates_supplier, nil)
      end
      if params[:columns]['3'].present? && params[:columns]['3'][:search][:value].present?
        q = params[:columns]['3'][:search][:value]
        byebug
        if is_number?(q)
          q = User.find_by(name: q).try(:id)
        end
        #sticky(:dt_candidates_status, q)
        versions = versions.where(whodunnit: q) unless q.blank?
      #else
      #  sticky(:dt_candidates_status, nil)
      end
      if params[:columns]['4'].present? && params[:columns]['4'][:search][:value].present?
        q = params[:columns]['4'][:search][:value]
        start_on, end_on = q.split('-').map(&:strip)
        #sticky(:dt_candidates_hotel_chain_id, q)
        versions = versions.where(created_at: Chronic.parse(start_on)..Chronic.parse(end_on)) unless q.blank?
      #else
        #sticky(:dt_candidates_hotel_chain_id, nil)
      end
    end

    # Start organic search
    search_terms = params[:search][:value]
    if search_terms.present?
      versions = versions.where('versions.object like :search', search: "%#{search_terms}%")
    end
    if params[:type]
      versions = versions.where(:item_type => params[:type])
    end
    if params[:id]
      versions = versions.where(:item_id => params[:id])
    end

    versions = versions.page(page_count).per(per_page)
  end

  def columns
    ['versions.created_at, versions.item_type, versions.item_id, versions.event, versions.whodunnit, versions.object, versions.object_changes, versions.id']
  end

  def change_time(version)
    tags = [content_tag(:span, "Change #{version.id}", class: 'change_id')]
    tags << content_tag(:div, version.created_at.strftime('%Y-%m-%d'), class: 'date')
    tags << content_tag(:div, version.created_at.strftime('%H:%M:%S'), class: 'date')
    tags.join()
  end

  def change_details(version)
    tags = [content_tag(:strong, version.event, class: 'event')]
    tags << change_item_link(version)
    tags << user(version)
    html = [content_tag(:p, tags.join(' ').html_safe, class: 'change_details_description')]
    html << change_table(version) if ['create','update'].include?(version.event)
    html.join('')
  end

  def rollback(version)
    link_to(t('rollback').html_safe, change_path(version), :method => 'put', :class => 'rollback btn btn-warning btn-xs', :data => { :confirm => 'Are you sure?' })
  end

  private
  def user(version)
    return unless PaperTrailManager.whodunnit_class && version.whodunnit
    if is_number?(version.whodunnit)
      user = PaperTrailManager.whodunnit_class.find(version.whodunnit)
    else
      user = PaperTrailManager.whodunnit_class.find_by(name: version.whodunnit)
    end
    if user
      if PaperTrailManager.user_path_method
        link = link_to(user.send(PaperTrailManager.whodunnit_name_method).html_safe, send(PaperTrailManager.user_path_method.to_sym, user))
      else
        link = user.send(PaperTrailManager.whodunnit_name_method).html_safe
      end
    else
      link = version.whodunnit
    end
    return "by #{link}"
  end

  def is_number?(value)
    true if Float(value) rescue false
  end

  def change_table(version)
    changes = changes_for(version)
    return if changes.empty?
    table_html = [table_header, table_body(changes)].join('').html_safe
    content_tag(:table, table_html, class: 'change_details_table table table-striped table-condensed')
  end

  def table_header
    th = content_tag(:dl, class: 'dl-horizontal') do
      html = content_tag(:dt, 'Attribute changed:')
      html += content_tag(:dd, "From &rarr; To".html_safe)
      html
    end
    content_tag(:thead) do
      content_tag(:tr) do
        content_tag(:th, th.html_safe)
      end
    end
  end

  def table_body(changes)
    rows = []
    changes.keys.sort.each_with_index do |key, i|
      stuff = [text_or_nil(changes[key][:previous])]
      stuff << "&rarr;".html_safe
      stuff << text_or_nil(changes[key][:current])
      html = content_tag(:dt, "#{key}: ")
      html += content_tag(:dd, stuff.join(' ').html_safe)
      rows << html
    end
    body = content_tag(:tr) do
      content_tag(:td, content_tag(:dl, rows.join('').html_safe, class: 'dl-horizontal'))
    end
    content_tag(:tbody, body)
  end
end
