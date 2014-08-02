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

  $('.chart').each(function() {
    $(this).highcharts({
      chart: {
        backgroundColor: '#eee',
        plotBackgroundColor: '#eee',
        plotShadow: false
      },
      title: false,
      credits: false,
      tooltip: {
        pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
      },
      plotOptions: {
        pie: {
          allowPointSelect: true,
          cursor: 'pointer',
          dataLabels: {
            enabled: true,
            format: '<b>{point.name}</b>: {point.percentage:.1f} %',
            style: {
                color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black'
            }
          }
        }
      },
      series: [{
          type: 'pie',
          name: 'Percentage',
          data: $(this).data('series')
      }]
    });
  });
});
