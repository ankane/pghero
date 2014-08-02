//= require jquery
//= require dataTables/jquery.dataTables

$.fn.dataTable.ext.order['data-value'] = function (settings, col) {
  return this.api().column(col, {order: 'index'}).nodes().map(function(td, i) {
    return parseInt($(td).data('value'));
  });
};

$.extend($.fn.dataTable.defaults, {
  paging: false,
  searching: false,
  info: false
});

$(function() {
  $('table.space').dataTable({
    columnDefs: [
      { 'orderDataType': 'data-value', 'targets': 2, 'type': 'numeric' }
    ],
    order: [[2, 'desc']]
  });

  $('table.indexes').dataTable({
    columnDefs: [
      { 'orderDataType': 'data-value', 'targets': 2, 'type': 'numeric' },
      { 'targets': 1, 'orderDataType': 'numeric' }
    ],
    order: [[2, 'desc']]
  });
});
