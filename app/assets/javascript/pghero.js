//= require jquery
//= require dataTables/jquery.dataTables

$.fn.dataTable.ext.order['data-bytes'] = function (settings, col) {
  return this.api().column(col, {order: 'index'}).nodes().map(function(td, i) {
    return parseInt($(td).data('byte-size'));
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
      { 'orderDataType': 'data-bytes', 'targets': [2], 'type': 'numeric' }
    ],
    order: [[2, 'desc']]
  });

  $('table.indexes').dataTable({
    columnDefs: [
      { 'targets': [1, 2], 'type': 'numeric' }
    ],
    order: [[2, 'desc']]
  });
});
