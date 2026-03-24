const BACKEND = "https://stream.webcamlivornomare.it";
const FRAME = BACKEND + "/frame.jpg";
const VARIANTS = ["webcam_high", "webcam_mid", "webcam_low",];
const FALLBACK_INTERVAL = 2000;

// DOM elements

const video = document.getElementById("video-webcam");
const spinner = document.getElementById("info");

// Helper functions

// Play video + error handling
function play() {
  video.play()
    .then(_ => {
      showVideo();
    })
    .catch(_ => {
      showFallback();
    })
}

function showVideo() {
  video.style.display = 'block'
  spinner.style.display = 'none'
}

function showSpinner() {
  video.style.display = 'none'
  spinner.style.display = 'flex'
}

function showFallback() {
  if (hls) {
    hls.destroy();
    hls = undefined;
  }
  refreshImage();
}

let refreshImageTimeout;

function refreshImage() {
  fetch(FRAME + "#" + new Date().getTime())
    .then(response => response.blob())
    .then(blob => {
      showVideo();
      video.poster = URL.createObjectURL(blob);
      refreshImageTimeout = setTimeout(() => {
        refreshImage();
      }, FALLBACK_INTERVAL);
    })
    .catch(_ => {
      showSpinner();
      refreshImageTimeout = setTimeout(_ => {
        refreshImage();
      }, 5000);
    })
}

/**
 * Fetches a specific video variant from the backend server
 * @param {string} variant - The variant quality to fetch
 * @param {boolean} includeHeader - Whether to include the header in the response
 * @returns {Promise<string>} The M3U8 playlist content
 */
async function fetchVariant(variant, includeHeader) {
  const response = await fetch(BACKEND + "/" + variant + "/index.m3u8");
  const text = await response.text();
  const match = text.match(/(#EXT-X-STREAM-INF.*$\n)(.*$)/m);

  let result = "";

  if (includeHeader) {
    result = text.replace(match[0], "");
  }

  if (match.length > 0) {
    result += match[1] + "\n" + BACKEND + "/" + variant + "/" + match[2] + "\n";
  }

  return result;
}

/**
 * Builds the master M3U8 playlist by combining all variants
 * @returns {Promise<string>} The combined master playlist
 */
async function buildMaster() {
  let masterPlaylist = "";

  for (let i = 0; i < VARIANTS.length; i++) {
    masterPlaylist += await fetchVariant(VARIANTS[i], i === 0);
    masterPlaylist += "\n";
  }

  return masterPlaylist;
}

// Event listeners

video.addEventListener("playing", _ => {
  showVideo();
})

video.addEventListener("pause", _ => {
  play();
})

video.addEventListener("click", _ => {
  if (hls && video.paused) {
    play();
    return;
  }

  if (isFullscreen()) {
    exitFS();
  } else {
    requestFS(video);
  }
})

// HLS.js initialization

let retries = 0;
const MAX_RETRIES = 5;

let hls;
function initHls(sourceUrl) {
  hls = new Hls({
    startLevel: -1,
    fragLoadingMaxRetry: 3,
    manifestLoadingMaxRetry: 2,
    enableWorker: true,
    lowLatencyMode: true,
    backBufferLength: 90
  });

  hls.loadSource(sourceUrl);
  hls.attachMedia(video);

  hls.on(Hls.Events.MANIFEST_PARSED, _ => {
    play();
  });

  hls.on(Hls.Events.ERROR, function (_, data) {
    if (data.fatal) {
      showSpinner();

      if (retries < MAX_RETRIES) {
        retries++;
        setTimeout(function () {
          hls.destroy();
          initHls(sourceUrl);
        }, 5000);
      } else {
        hls.destroy();
        showFallback();
      }
    }
  });
}

if (Hls.isSupported()) {
  buildMaster().then((masterPlaylist) => {
    const blob = new Blob([masterPlaylist], {
      type: "application/vnd.apple.mpegurl"
    });
    initHls(URL.createObjectURL(blob));
  });
} else {
  showFallback();
}

// Fullscreen logic

function isFullscreen() {
  return document.fullscreenElement ||
    document.webkitFullscreenElement ||
    document.mozFullScreenElement ||
    document.msFullscreenElement;
}

function requestFS(element) {
  const requestMethod = element.requestFullscreen?.bind(element) ||
    element.webkitRequestFullscreen?.bind(element) ||
    element.mozRequestFullScreen?.bind(element) ||
    element.msRequestFullscreen?.bind(element);

  requestMethod?.()?.catch?.(_ => { });
}

function exitFS() {
  const exitMethod = document.exitFullscreen?.bind(document) ||
    document.webkitExitFullscreen?.bind(document) ||
    document.mozCancelFullScreen?.bind(document) ||
    document.msExitFullscreen?.bind(document);

  exitMethod?.()?.catch?.(_ => { });
}
