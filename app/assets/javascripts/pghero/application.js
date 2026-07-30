//= require ./nouislider
//= require ./Chart.bundle
//= require ./chartkick
//= require ./highlight.min

function highlightQueries() {
  document.querySelectorAll("code.language-pgsql").forEach(function (block, i) {
    if (!block.dataset.highlighted) {
      hljs.highlightElement(block);
    }
  });
}

function initSlider() {
  function roundTime(time) {
    const period = 1000 * 60 * 5;
    return new Date(Math.ceil(time.getTime() / period) * period);
  }

  function pad(num) {
    return num < 10 ? "0" + num : num;
  }

  const days = 1;
  const now = new Date();
  const sliderStartAt = roundTime(now) - days * 24 * 60 * 60 * 1000;
  const sliderMax = 24 * 12 * days;

  startAt = startAt || sliderStartAt;
  const min = startAt > 0 ? (startAt - sliderStartAt) / (1000 * 60 * 5) : 0;

  const max = endAt > 0 ? (endAt - sliderStartAt) / (1000 * 60 * 5) : sliderMax;

  const slider = document.getElementById("slider");

  noUiSlider.create(slider, {
    range: {
      min: 0,
      max: sliderMax
    },
    step: 1,
    connect: true,
    start: [min, max]
  });

  // remove outline for mouse only
  const handle = document.querySelector(".noUi-handle");
  handle.addEventListener("mousedown", function (e) {
    e.target.classList.add("no-outline");
  });
  handle.addEventListener("blur", function (e) {
    e.target.classList.remove("no-outline");
  });

  function updateText() {
    const values = slider.noUiSlider.get();
    setText("#range-start", values[0]);
    setText("#range-end", values[1]);
  }

  function setText(selector, offset) {
    const time = timeAt(offset);

    let html = "";
    if (time === now) {
      if (selector === "#range-end") {
        html = "Now";
      }
    } else {
      html = time.toLocaleDateString(undefined, {month: 'short', day: 'numeric'}) + " " + pad(time.getHours()) + ":" + pad(time.getMinutes());
    }
    document.querySelector(selector).textContent = html;
  }

  function timeAt(offset) {
    const time = new Date(sliderStartAt + offset * 5 * 60 * 1000);
    return time > now ? now : time;
  }

  function timeParam(time) {
    return time.toISOString().replace(/\.000Z$/, "Z");
  }

  function queriesPath(params) {
    let path = "queries";
    if (params.start_at || params.end_at || params.sort || params.min_average_time || params.min_calls || params.user || params.debug) {
      path += "?" + (new URLSearchParams(params)).toString();
    }
    return path;
  }

  function refreshStats(push) {
    const values = slider.noUiSlider.get();
    const startAt = push ? timeAt(values[0]) : new Date(window.startAt);
    const endAt = timeAt(values[1]);

    const params = {};
    if (startAt.getTime() != sliderStartAt) {
      params.start_at = timeParam(startAt);
    }
    if (endAt < now) {
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
    if (user) {
      params.user = user;
    }
    if (debug) {
      params.debug = debug;
    }

    const showAll = document.getElementById("show-all");
    if (showAll) {
      const showAllParams = Object.assign({}, params);
      delete showAllParams.user;
      showAll.setAttribute("href", queriesPath(showAllParams));
    }

    document.querySelectorAll(".queries-table th a").forEach(function (link) {
      const linkParams = Object.assign({}, params, {sort: link.getAttribute("data-sort")});
      link.setAttribute("href", queriesPath(linkParams));
    });

    const queries = document.getElementById("queries");
    queries.innerHTML = '<tr><td colspan="3"><p class="queries-info text-muted">...</p></td></tr>';
    const path = queriesPath(params);
    fetch(path, {headers: {"X-Requested-With": "XMLHttpRequest"}})
      .then(function (response) {
        if (!response.ok) {
          throw new Error(response.statusText);
        }
        return response.text();
      })
      .then(function (text) {
        queries.innerHTML = text;
        highlightQueries();
      })
      .catch(function (error) {
        const queriesInfo = document.querySelector(".queries-info");
        queriesInfo.style.color = "red";
        queriesInfo.textContent = error.message;
      });

    if (push && history.pushState) {
      history.pushState(null, null, path);
    }
  }

  slider.noUiSlider.on("slide", updateText);
  slider.noUiSlider.on("change", function () {
    refreshStats(true);
  });
  updateText();
  document.addEventListener("DOMContentLoaded", function () {
    refreshStats(false);
  });
}

document.addEventListener("click", function (e) {
  const target = e.target.closest(".query-code");
  if (target) {
    target.style.maxHeight = "none";
  }
});

document.addEventListener("click", function (e) {
  const target = e.target.closest(".migration-link");
  if (target) {
    e.preventDefault();
    target.parentElement.nextElementSibling.style.display = "block";
  }
});

document.addEventListener("click", function (e) {
  const target = e.target.closest(".show-details");
  if (target) {
    target.nextElementSibling.nextElementSibling.style.display = "block";
    target.style.display = "none";
  }
});

document.addEventListener("click", function (e) {
  const target = e.target.closest("#copy");
  if (target) {
    const explanation = document.getElementById("explanation").textContent;
    navigator.clipboard.writeText(explanation).then(function () {
      const buttonText = target.textContent;
      target.textContent = "Copied!";
      setTimeout(function () {
        target.textContent = buttonText;
      }, 2000);
    });
  }
});

document.addEventListener("DOMContentLoaded", function () {
  const copyButton = document.getElementById("copy");
  if (copyButton && navigator.clipboard) {
    copyButton.classList.remove("hide");
  }
});
