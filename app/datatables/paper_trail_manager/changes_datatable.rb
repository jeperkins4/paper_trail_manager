class PaperTrailManager::ChangesDatatable < PaperTrailManager::BaseDatatable
  delegate :current_user, :change_path, :user_path, :change_show_allowed?, :changes_for, :change_title_for, :change_item_types, :change_item_link, :version_reify, :text_or_nil, to: :@view

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

    search_terms = params[:search][:value]
    if params[:search].present?
      versions = versions.where('versions.whodunnit like :search or versions.item_type like :search or versions.object like :search or versions.event = :search', search: "%#{search_terms}%")
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
    html << change_table(version)
    html.join('')
  end

  def rollback(version)
    link_to(t('rollback').html_safe, change_path(version), :method => 'put', :class => 'rollback btn btn-warning btn-xs', :data => { :confirm => 'Are you sure?' })
  end

  private
  def user(version)
    return unless PaperTrailManager.whodunnit_class && version.whodunnit
    user = PaperTrailManager.whodunnit_class.find(version.whodunnit)
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

  def change_table(version)
    changes = changes_for(version)
    return if changes.empty?
    table_html = [table_header, table_body(changes)].join('').html_safe
    content_tag(:table, table_html, class: 'change_details_table table table-striped table-condensed')
  end

  def table_header
    th = [content_tag(:th, 'Attribute changed')]
    th << content_tag(:th, 'From')
    th << content_tag(:th)
    th << content_tag(:th, 'To')
    content_tag(:thead, content_tag(:tr, th.join('').html_safe))
  end

  def table_body(changes)
    rows = []
    changes.keys.sort.each_with_index do |key, i|
      td = [content_tag(:td, key, class: 'change_detail_key previous')]
      td << content_tag(:td, text_or_nil(changes[key][:previous]), class: 'change_detail_value previous')
      td << content_tag(:td, "&rarr;".html_safe, class: 'change_detail_spacer')
      td << content_tag(:td, text_or_nil(changes[key][:current]), class: 'change_detail_value current')
      row = i % 2 == 0 ? 'even' : 'odd'
      rows << content_tag(:tr, td.join('').html_safe, class: row)
    end
    content_tag(:tbody, rows.join('').html_safe)
  end
end
