$ ->
  $('.key').popover
    html: true

  cTable = $("#changes_table").DataTable
    dom: "<'row'<'col-md-7'l><'col-md-5'f>r>t<'row'<'col-md-7'i><'col-md-5'p>>"
    pagingType: "simple_numbers"
    autoWidth: false
    processing: true
    serverSide: true
    order: [[0, 'desc']]
    ajax: $("#changes_table").data('source')

  $('input[name="change_date"]').daterangepicker
    ranges:
      "Next 7 Days": [
        moment()
        moment().subtract("days", 6)
      ]
      "Next 30 Days": [
        moment()
        moment().subtract("days", 29)
      ]
      "This Month": [
        moment().startOf("month")
        moment().endOf("month")
      ]
      "Last Month": [
        moment().subtract("month", 1).startOf("month")
        moment().subtract("month", 1).endOf("month")
      ]

    startDate: moment().subtract("days", 29)
    endDate: moment()
  , (start, end) ->
    $('input[name="change_date"]').val start.format("MM/DD/YYYY") + " - " + end.format("MM/DD/YYYY")
    return

  $(".filters select").change ->
    cTable.column(1).search($("#change_model option:selected").val())
      .column(1).search($("#change_model option:selected").val())
      .column(2).search($("#change_action option:selected").val())
      .column(3).search($("#change_user option:selected").val())
      .column(4).search($("#change_date").val())
      .draw()
