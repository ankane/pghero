//= require ./jquery
//= require ./jquery.nouislider.min
//= require ./Chart.bundle
//= require ./chartkick
//= require ./highlight.pack

function highlightQueries() {
  $("pre code").each(function(i, block) {
    hljs.highlightBlock(block);
  });
}

function initSlider() {
  var period = 1000 * 60 * 5; // 5 minutes
  var latestTimestamp = new Date(latest).getTime();
  var earliestTimestamp = new Date(earliest).getTime();
  var startTimestamp = new Date(startAt).getTime();
  var endTimestamp = new Date(endAt).getTime();

  var $slider = $("#slider");

  $slider.noUiSlider({
    range: {
      min: earliestTimestamp,
      max: latestTimestamp
    },
    step: period,
    connect: true,
    start: [startTimestamp, endTimestamp]
  });

  function updateText() {
    var values = $slider.val();
    setText("#range-start", values[0]);
    setText("#range-end", values[1]);
  }

  function setText(selector, timestamp) {
    var time = timeAt(timestamp)

    var html = "";
    if (time == latest) {
      if (selector == "#range-end") {
        html = "Now";
      }
    } else {
      html = time.toLocaleString();
    }
    $(selector).html(html);
  }

  function timeAt(time) {
    var time = new Date(Math.round(time));
    return (time > latest) ? latest : time;
  }

  function timeParam(time) {
    return time.toISOString();
  }

  function queriesPath(params) {
    var path = "queries";
    if (params.start_at || params.end_at || params.sort || params.min_average_time || params.min_calls || params.debug) {
      path += "?" + $.param(params);
    }
    return path;
  }

  function refreshStats(push) {
    var values = $slider.val();
    var startAt = push ? timeAt(values[0]) : new Date(window.startAt);
    var endAt = timeAt(values[1]);

    var params = {}
    params.start_at = timeParam(startAt);
    if (endAt < latest) {
      params.end_at = timeParam(endAt);
    }
    if (sort) {
      params.sort = sort;
    }
    if (minAverageTime) {
      params.min_average_time = minAverageTime;
    }
    if (minCalls) {
      params.min_calls = minCalls;
    }
    if (debug) {
      params.debug = debug;
    }

    var path = queriesPath(params);

    $(".queries-table th a").each( function () {
      var p = $.extend({}, params, {sort: $(this).data("sort"), min_average_time: minAverageTime, min_calls: minCalls, debug: debug});
      if (!p.sort) {
        delete p.sort;
      }
      if (!p.min_average_time) {
        delete p.min_average_time;
      }
      if (!p.min_calls) {
        delete p.min_calls;
      }
      if (!p.debug) {
        delete p.debug;
      }
      $(this).attr("href", queriesPath(p));
    });


    var callback = function (response, status, xhr) {
      if (status === "error" ) {
        $(".queries-info").css("color", "red").html(xhr.status + " " + xhr.statusText);
      } else {
        highlightQueries();
      }
    };
    $("#queries").html('<tr><td colspan="3"><p class="queries-info text-muted">...</p></td></tr>').load(path, callback);

    if (push && history.pushState) {
      history.pushState(null, null, path);
    }
  }

  $slider.on("slide", updateText).on("change", function () {
    refreshStats(true);
  });
  updateText();
  $( function () {
    refreshStats(false);
  });
}
