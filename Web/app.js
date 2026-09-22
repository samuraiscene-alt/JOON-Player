(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const ids = ["home","player","videos","video","stage","dim","subs","gesture","feedback","controls","unlock","openTop","openMain","add","back","name","pos","now","dur","seek","play","rew","fwd","prev","next","lock","mute","full","settingsBtn","queueBtn","settings","queue","rates","fits","setA","setB","clearAB","sleep","pip","srt","subMinus","subReset","subPlus","subSmall","subSize","subLarge","subPos","repeat","shuffle","list","toast","notice"];
  const e = Object.fromEntries(ids.map((id) => [id, $(id)]));

  const K = {
    rate: "jp.web.rate",
    fit: "jp.web.fit",
    subSize: "jp.web.subSize",
    subPos: "jp.web.subPos",
    resume: "jp.web.resume."
  };

  const state = {
    items: [],
    originalOrder: [],
    index: -1,
    objectURL: null,
    repeat: "off",
    shuffle: false,
    locked: false,
    hideTimer: null,
    toastTimer: null,
    feedbackTimer: null,
    a: null,
    b: null,
    sleepTimer: null,
    sleepAtEnd: false,
    cues: [],
    subtitleDelay: 0,
    subtitleSize: Number(localStorage.getItem(K.subSize) || 100),
    subtitlePosition: localStorage.getItem(K.subPos) || "low",
    brightness: 1,
    gesture: null,
    holdTimer: null,
    temporaryRate: null,
    lastTapAt: 0,
    tapTimer: null,
    lastResumeSave: 0
  };

  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

  function formatTime(value) {
    if (!Number.isFinite(value) || value < 0) return "0:00";
    const total = Math.floor(value);
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    if (h) return h + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
    return m + ":" + String(s).padStart(2, "0");
  }

  function fingerprint(file) {
    return encodeURIComponent(file.name + "|" + file.size + "|" + file.lastModified);
  }

  function showToast(message, duration) {
    clearTimeout(state.toastTimer);
    e.toast.textContent = message;
    e.toast.hidden = false;
    state.toastTimer = setTimeout(() => { e.toast.hidden = true; }, duration || 1800);
  }

  function showFeedback(message) {
    clearTimeout(state.feedbackTimer);
    e.feedback.textContent = message;
    e.feedback.hidden = false;
    state.feedbackTimer = setTimeout(() => { e.feedback.hidden = true; }, 650);
  }

  function closeSheets() {
    e.settings.hidden = true;
    e.queue.hidden = true;
  }

  function openSheet(sheet) {
    closeSheets();
    sheet.hidden = false;
    showControls(true);
  }

  function revokeObjectURL() {
    if (!state.objectURL) return;
    URL.revokeObjectURL(state.objectURL);
    state.objectURL = null;
  }

  function supportText() {
    return "현재 Web 버전은 MP4 / M4V / MOV 동영상만 선택할 수 있어.";
  }

  function addFiles(fileList, replace) {
    const files = Array.from(fileList || []).filter((file) =>
      /\.(mp4|m4v|mov)$/i.test(file.name)
    );

    if (!files.length) {
      showToast("동영상 파일을 선택해줘.");
      return;
    }

    if (replace) {
      revokeObjectURL();
      state.items = [];
      state.originalOrder = [];
      state.index = -1;
    }

    const added = files.map((file) => ({
      file,
      id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + "-" + String(Math.random())
    }));

    state.items.push(...added);
    state.originalOrder.push(...added);
    renderList();

    if (state.index < 0) playIndex(0, true);
    else showToast(String(files.length) + "개 파일을 추가했어.");
  }

  function playIndex(index, allowResume) {
    if (!state.items.length) return;

    state.index = clamp(index, 0, state.items.length - 1);
    const item = state.items[state.index];

    revokeObjectURL();
    state.objectURL = URL.createObjectURL(item.file);
    e.video.src = state.objectURL;
    e.video.load();

    e.name.textContent = item.file.name;
    e.pos.textContent = String(state.index + 1) + " / " + String(state.items.length);
    e.home.hidden = true;
    e.player.hidden = false;
    document.body.classList.add("player-active");
    e.notice.textContent = supportText(item.file);

    state.a = null;
    state.b = null;
    state.cues = [];
    state.subtitleDelay = 0;
    e.subs.textContent = "";
    e.subReset.textContent = "0.0s";

    function onLoadedMetadata() {
      e.video.removeEventListener("loadedmetadata", onLoadedMetadata);
      e.seek.max = String(e.video.duration || 1);
      e.dur.textContent = formatTime(e.video.duration);

      if (allowResume !== false) {
        const stored = Number(localStorage.getItem(K.resume + fingerprint(item.file)) || 0);
        if (stored >= 10 && Number.isFinite(e.video.duration) && e.video.duration - stored >= 30) {
          e.video.currentTime = stored;
          showToast(formatTime(stored) + "에서 이어볼게.");
        }
      }

      e.video.play().catch(() => {});
      scheduleHide();
    }

    e.video.addEventListener("loadedmetadata", onLoadedMetadata);
    renderList();
    updateNavigation();
  }

  function renderList() {
    e.list.innerHTML = "";

    state.items.forEach((item, index) => {
      const li = document.createElement("li");
      li.className = "item" + (index === state.index ? " current" : "");

      const main = document.createElement("button");
      main.innerHTML = "<strong></strong><small></small>";
      main.querySelector("strong").textContent = item.file.name;
      main.querySelector("small").textContent =
        (item.file.size / 1048576).toFixed(item.file.size > 104857600 ? 0 : 1) + " MB";
      main.addEventListener("click", () => {
        playIndex(index, true);
        closeSheets();
      });

      const remove = document.createElement("button");
      remove.textContent = "삭제";
      remove.addEventListener("click", () => removeItem(index));

      li.append(main, remove);
      e.list.append(li);
    });
  }

  function removeItem(index) {
    const removingCurrent = index === state.index;
    state.items.splice(index, 1);
    state.originalOrder = state.originalOrder.filter((item) =>
      state.items.some((current) => current.id === item.id)
    );

    if (!state.items.length) {
      revokeObjectURL();
      state.index = -1;
      e.video.removeAttribute("src");
      e.player.hidden = true;
      e.home.hidden = false;
      document.body.classList.remove("player-active");
      closeSheets();
      return;
    }

    if (removingCurrent) {
      state.index = Math.min(index, state.items.length - 1);
      playIndex(state.index, true);
    } else if (index < state.index) {
      state.index -= 1;
    }

    renderList();
    updateNavigation();
  }

  function updateNavigation() {
    const hasMany = state.items.length > 1;
    e.prev.disabled = !hasMany || (state.index === 0 && state.repeat !== "all");
    e.next.disabled = !hasMany || (state.index === state.items.length - 1 && state.repeat !== "all");
    e.pos.textContent = state.index >= 0
      ? String(state.index + 1) + " / " + String(state.items.length)
      : "0 / 0";
  }

  function next(fromEnded) {
    if (fromEnded && state.repeat === "one") {
      e.video.currentTime = 0;
      e.video.play().catch(() => {});
      return;
    }

    if (state.index < state.items.length - 1) {
      playIndex(state.index + 1, true);
      return;
    }

    if (state.repeat === "all") {
      playIndex(0, true);
      return;
    }

    if (!fromEnded) showToast("마지막 영상이야.");
  }

  function previous() {
    if (state.index > 0) {
      playIndex(state.index - 1, true);
      return;
    }

    if (state.repeat === "all" && state.items.length > 1) {
      playIndex(state.items.length - 1, true);
    }
  }

  function seekBy(seconds) {
    if (!Number.isFinite(e.video.duration)) return;
    e.video.currentTime = clamp(e.video.currentTime + seconds, 0, e.video.duration);
    showFeedback((seconds > 0 ? "+" : "") + String(seconds) + "초");
  }

  function showControls(force) {
    if (state.locked && !force) return;
    e.controls.classList.remove("hide");
    clearTimeout(state.hideTimer);
  }

  function hideControls() {
    if (!state.locked) e.controls.classList.add("hide");
  }

  function scheduleHide() {
    clearTimeout(state.hideTimer);
    if (!e.video.paused && !state.locked) {
      state.hideTimer = setTimeout(hideControls, 3000);
    }
  }

  function setPlaybackRate(value, persist) {
    const rate = Number(value) || 1;
    e.video.playbackRate = rate;

    if (persist !== false) localStorage.setItem(K.rate, String(rate));

    e.rates.querySelectorAll("[data-rate]").forEach((button) => {
      button.classList.toggle("on", Number(button.dataset.rate) === rate);
    });
  }

  function setFit(value, persist) {
    e.stage.dataset.fit = value;
    if (persist !== false) localStorage.setItem(K.fit, value);

    e.fits.querySelectorAll("[data-fit]").forEach((button) => {
      button.classList.toggle("on", button.dataset.fit === value);
    });
  }

  function persistResume(force) {
    const item = state.items[state.index];
    if (!item || !Number.isFinite(e.video.duration)) return;

    const now = Date.now();
    if (!force && now - state.lastResumeSave < 5000) return;
    state.lastResumeSave = now;

    const key = K.resume + fingerprint(item.file);
    const current = e.video.currentTime;
    const remaining = e.video.duration - current;

    if (current >= 10 && remaining >= 30) localStorage.setItem(key, String(current));
    else localStorage.removeItem(key);
  }

  function updateTimeline() {
    e.now.textContent = formatTime(e.video.currentTime);

    if (Number.isFinite(e.video.duration)) {
      e.seek.max = String(e.video.duration);
      e.seek.value = String(e.video.currentTime);
    }

    if (state.a !== null && state.b !== null && e.video.currentTime >= state.b) {
      e.video.currentTime = state.a;
    }

    updateSubtitle();
    persistResume(false);
  }

  function updatePlayButton() {
    e.play.textContent = e.video.paused ? "▶" : "❚❚";
    if (e.video.paused) showControls(true);
    else scheduleHide();
  }

  function setAB(which) {
    if (which === "a") {
      state.a = e.video.currentTime;
      if (state.b !== null && state.b <= state.a) state.b = null;
      showToast("A: " + formatTime(state.a));
      return;
    }

    if (state.a === null) state.a = 0;
    state.b = Math.max(e.video.currentTime, state.a + 0.2);
    showToast("B: " + formatTime(state.b));
  }

  function setSleepTimer(value) {
    clearTimeout(state.sleepTimer);
    state.sleepTimer = null;
    state.sleepAtEnd = false;

    if (value === "off") return;

    if (value === "end") {
      state.sleepAtEnd = true;
      showToast("현재 영상이 끝나면 멈출게.");
      return;
    }

    const minutes = Number(value);
    state.sleepTimer = setTimeout(() => {
      e.video.pause();
      e.sleep.value = "off";
      showToast("취침 타이머가 끝났어.");
    }, minutes * 60000);

    showToast(String(minutes) + "분 뒤에 멈출게.");
  }

  function parseSRT(text) {
    return text.replace(/\r/g, "").trim().split(/\n{2,}/).map((block) => {
      const lines = block.split("\n");
      const index = lines.findIndex((line) => line.includes("-->"));
      if (index < 0) return null;

      const match = lines[index].match(/(\d+):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d+):(\d{2}):(\d{2})[,.](\d{3})/);
      if (!match) return null;

      const toSeconds = (h, m, s, ms) => Number(h) * 3600 + Number(m) * 60 + Number(s) + Number(ms) / 1000;
      const cueText = lines.slice(index + 1).join("\n").replace(/<[^>]+>/g, "").trim();

      return cueText ? {
        start: toSeconds(match[1], match[2], match[3], match[4]),
        end: toSeconds(match[5], match[6], match[7], match[8]),
        text: cueText
      } : null;
    }).filter(Boolean);
  }

  async function loadSRT(file) {
    try {
      state.cues = parseSRT(await file.text());
      state.subtitleDelay = 0;
      e.subReset.textContent = "0.0s";
      showToast(file.name + " · " + String(state.cues.length) + "개 자막");
    } catch {
      showToast("자막 파일을 읽지 못했어.");
    }
  }

  function updateSubtitle() {
    const t = e.video.currentTime - state.subtitleDelay;
    const cue = state.cues.find((item) => t >= item.start && t <= item.end);
    e.subs.textContent = cue ? cue.text : "";
  }

  function adjustSubtitleDelay(delta) {
    state.subtitleDelay = clamp(
      Math.round((state.subtitleDelay + delta) * 10) / 10,
      -10,
      10
    );

    e.subReset.textContent =
      (state.subtitleDelay > 0 ? "+" : "") + state.subtitleDelay.toFixed(1) + "s";
    updateSubtitle();
  }

  function setSubtitleSize(value) {
    state.subtitleSize = clamp(Math.round(value / 10) * 10, 60, 180);
    e.subs.style.fontSize = String(state.subtitleSize) + "%";
    e.subSize.textContent = String(state.subtitleSize) + "%";
    localStorage.setItem(K.subSize, String(state.subtitleSize));
  }

  function setSubtitlePosition(value) {
    state.subtitlePosition = value;
    e.subs.className = "subs " + (value === "mid" ? "mid" : value === "high" ? "high" : "");
    e.subPos.value = value;
    localStorage.setItem(K.subPos, value);
  }

  async function togglePiP() {
    try {
      if (document.pictureInPictureElement) {
        await document.exitPictureInPicture();
        return;
      }

      if (e.video.webkitPresentationMode && e.video.webkitSetPresentationMode) {
        const mode = e.video.webkitPresentationMode === "picture-in-picture"
          ? "inline"
          : "picture-in-picture";
        e.video.webkitSetPresentationMode(mode);
        return;
      }

      if (e.video.requestPictureInPicture) {
        await e.video.requestPictureInPicture();
        return;
      }

      showToast("이 Safari에서는 웹 PiP를 사용할 수 없어.");
    } catch {
      showToast("PiP 전환에 실패했어.");
    }
  }

  async function setWebFullscreen(value) {
    const enabled = Boolean(value);
    e.stage.classList.toggle("web-fullscreen", enabled);
    document.body.classList.toggle("player-fullscreen", enabled);
    e.full.setAttribute("aria-label", enabled ? "전체화면 종료" : "전체화면");
    showControls(true);
    scheduleHide();

    try {
      if (screen.orientation) {
        if (enabled && screen.orientation.lock) {
          await screen.orientation.lock("landscape");
        } else if (!enabled && screen.orientation.unlock) {
          screen.orientation.unlock();
        }
      }
    } catch {}
  }

  function toggleFullscreen() {
    setWebFullscreen(!e.stage.classList.contains("web-fullscreen"));
  }

  function cycleRepeat() {
    state.repeat = state.repeat === "off"
      ? "all"
      : state.repeat === "all"
        ? "one"
        : "off";

    e.repeat.textContent = state.repeat === "off"
      ? "반복 끔"
      : state.repeat === "all"
        ? "전체 반복"
        : "한 곡 반복";

    updateNavigation();
  }

  function toggleShuffle() {
    state.shuffle = !state.shuffle;
    e.shuffle.textContent = state.shuffle ? "셔플 켬" : "셔플 끔";

    const current = state.items[state.index];

    if (state.shuffle) {
      const rest = state.items.filter((item) => item.id !== (current && current.id));
      for (let i = rest.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1));
        const temp = rest[i];
        rest[i] = rest[j];
        rest[j] = temp;
      }

      state.items = current ? [current, ...rest] : rest;
      state.index = current ? 0 : -1;
    } else {
      state.items = state.originalOrder.filter((item) =>
        state.items.some((currentItem) => currentItem.id === item.id)
      );
      state.index = current
        ? state.items.findIndex((item) => item.id === current.id)
        : -1;
    }

    renderList();
    updateNavigation();
  }

  function setLocked(value) {
    state.locked = value;
    e.unlock.hidden = !value;

    if (value) {
      e.controls.classList.add("hide");
      showToast("컨트롤을 잠갔어.");
    } else {
      showControls(true);
      scheduleHide();
    }
  }

  function setupGestures() {
    const activePointers = new Map();
    let pinch = null;
    let suppressSingleUntilClear = false;

    function restoreTemporaryRate() {
      if (state.temporaryRate !== null) {
        e.video.playbackRate = state.temporaryRate;
        state.temporaryRate = null;
      }
    }

    function pointerDistance() {
      const points = Array.from(activePointers.values()).slice(0, 2);
      if (points.length < 2) return 0;
      return Math.hypot(
        points[1].x - points[0].x,
        points[1].y - points[0].y
      );
    }

    function releasePointer(event) {
      try {
        if (e.gesture.hasPointerCapture && e.gesture.hasPointerCapture(event.pointerId)) {
          e.gesture.releasePointerCapture(event.pointerId);
        }
      } catch {}
    }

    e.gesture.addEventListener("pointerdown", (event) => {
      if (state.locked) return;
      if (event.cancelable) event.preventDefault();

      try {
        e.gesture.setPointerCapture(event.pointerId);
      } catch {}

      activePointers.set(event.pointerId, {
        x: event.clientX,
        y: event.clientY
      });

      if (activePointers.size >= 2) {
        clearTimeout(state.holdTimer);
        restoreTemporaryRate();
        clearTimeout(state.tapTimer);
        state.lastTapAt = 0;
        suppressSingleUntilClear = true;

        if (state.gesture) {
          state.gesture.moved = true;
          state.gesture.mode = "pinch";
        }

        pinch = {
          startDistance: Math.max(pointerDistance(), 1),
          applied: null
        };
        return;
      }

      state.gesture = {
        id: event.pointerId,
        startX: event.clientX,
        startY: event.clientY,
        lastX: event.clientX,
        lastY: event.clientY,
        startTime: e.video.currentTime,
        startBrightness: state.brightness,
        mode: null,
        moved: false
      };

      clearTimeout(state.holdTimer);
      state.holdTimer = setTimeout(() => {
        if (!state.gesture || state.gesture.moved || e.video.paused || activePointers.size !== 1) return;
        state.temporaryRate = e.video.playbackRate;
        e.video.playbackRate = 2;
        state.gesture.mode = "hold";
        showFeedback("2× · 누르는 동안");
      }, 350);
    });

    e.gesture.addEventListener("pointermove", (event) => {
      if (!activePointers.has(event.pointerId)) return;
      if (event.cancelable) event.preventDefault();

      activePointers.set(event.pointerId, {
        x: event.clientX,
        y: event.clientY
      });

      if (pinch && activePointers.size >= 2) {
        clearTimeout(state.holdTimer);
        restoreTemporaryRate();

        const scale = pointerDistance() / pinch.startDistance;

        if (scale >= 1.12 && pinch.applied !== "cover") {
          setFit("cover", true);
          pinch.applied = "cover";
          showFeedback("화면 채우기");
        } else if (scale <= 0.88 && pinch.applied !== "contain") {
          setFit("contain", true);
          pinch.applied = "contain";
          showFeedback("원본 비율");
        }

        return;
      }

      const g = state.gesture;
      if (!g || g.id !== event.pointerId || suppressSingleUntilClear) return;

      const dx = event.clientX - g.startX;
      const dy = event.clientY - g.startY;
      g.lastX = event.clientX;
      g.lastY = event.clientY;

      if (Math.hypot(dx, dy) > 18) {
        g.moved = true;
        clearTimeout(state.holdTimer);

        if (g.mode === "hold") {
          restoreTemporaryRate();
        }
      }

      if (!g.mode && Math.max(Math.abs(dx), Math.abs(dy)) > 18) {
        if (Math.abs(dx) > Math.abs(dy) + 6) {
          g.mode = "seek";
        } else if (Math.abs(dy) > Math.abs(dx) + 6) {
          g.mode = g.startX < innerWidth / 2 ? "brightness" : "volume";
        }
      }

      if (g.mode === "seek" && Number.isFinite(e.video.duration)) {
        const target = clamp(g.startTime + dx * 0.12, 0, e.video.duration);
        const delta = Math.round(target - g.startTime);
        showFeedback(formatTime(target) + " · " + (delta > 0 ? "+" : "") + String(delta) + "초");
      } else if (g.mode === "brightness") {
        state.brightness = clamp(g.startBrightness - dy / 300, 0.35, 1);
        e.dim.style.opacity = String(1 - state.brightness);
        showFeedback("영상 밝기 " + String(Math.round(state.brightness * 100)) + "%");
      } else if (g.mode === "volume") {
        showFeedback("아이폰 볼륨은 측면 버튼으로 조절");
      }
    });

    function finishGesture(event) {
      activePointers.delete(event.pointerId);
      clearTimeout(state.holdTimer);

      if (suppressSingleUntilClear) {
        restoreTemporaryRate();
        releasePointer(event);

        if (activePointers.size === 0) {
          suppressSingleUntilClear = false;
          pinch = null;
          state.gesture = null;
        }
        return;
      }

      const g = state.gesture;
      if (!g || g.id !== event.pointerId) {
        releasePointer(event);
        return;
      }

      if (g.mode === "seek" && Number.isFinite(e.video.duration)) {
        e.video.currentTime = clamp(
          g.startTime + (g.lastX - g.startX) * 0.12,
          0,
          e.video.duration
        );
      }

      if (g.mode === "hold") {
        restoreTemporaryRate();
      }

      if (!g.moved && g.mode !== "hold") {
        const now = Date.now();

        if (now - state.lastTapAt < 320) {
          clearTimeout(state.tapTimer);
          state.lastTapAt = 0;
          seekBy(g.lastX < innerWidth / 2 ? -10 : 10);
        } else {
          state.lastTapAt = now;

          if (e.controls.classList.contains("hide")) {
            showControls(false);
            scheduleHide();
          } else {
            clearTimeout(state.hideTimer);
            hideControls();
          }
        }
      }

      releasePointer(event);
      state.gesture = null;
    }

    e.gesture.addEventListener("pointerup", finishGesture);
    e.gesture.addEventListener("pointercancel", finishGesture);
  }

  [e.openTop, e.openMain, e.add].forEach((button) => {
    button.addEventListener("click", () => e.videos.click());
  });

  e.videos.addEventListener("change", (event) => {
    addFiles(event.target.files, state.index < 0);
    event.target.value = "";
  });

  e.back.addEventListener("click", () => {
    persistResume(true);
    setWebFullscreen(false);
    e.video.pause();
    e.player.hidden = true;
    e.home.hidden = false;
    document.body.classList.remove("player-active");
  });

  e.play.addEventListener("click", () => {
    if (e.video.paused) e.video.play().catch(() => showToast("이 파일을 재생할 수 없어."));
    else e.video.pause();
  });

  e.rew.addEventListener("click", () => seekBy(-10));
  e.fwd.addEventListener("click", () => seekBy(10));
  e.prev.addEventListener("click", previous);
  e.next.addEventListener("click", () => next(false));

  e.seek.addEventListener("input", () => {
    e.now.textContent = formatTime(Number(e.seek.value));
  });

  e.seek.addEventListener("change", () => {
    e.video.currentTime = Number(e.seek.value);
    scheduleHide();
  });

  e.lock.addEventListener("click", () => setLocked(true));
  e.unlock.addEventListener("click", () => setLocked(false));

  e.mute.addEventListener("click", () => {
    e.video.muted = !e.video.muted;
    e.mute.classList.toggle("muted", e.video.muted);
    e.mute.setAttribute("aria-label", e.video.muted ? "음소거 해제" : "음소거");
  });

  e.full.addEventListener("click", toggleFullscreen);
  e.settingsBtn.addEventListener("click", () => openSheet(e.settings));
  e.queueBtn.addEventListener("click", () => openSheet(e.queue));

  document.querySelectorAll("[data-close]").forEach((button) => {
    button.addEventListener("click", () => { $(button.dataset.close).hidden = true; });
  });

  e.rates.addEventListener("click", (event) => {
    const button = event.target.closest("[data-rate]");
    if (button) setPlaybackRate(button.dataset.rate, true);
  });

  e.fits.addEventListener("click", (event) => {
    const button = event.target.closest("[data-fit]");
    if (button) setFit(button.dataset.fit, true);
  });

  e.setA.addEventListener("click", () => setAB("a"));
  e.setB.addEventListener("click", () => setAB("b"));

  e.clearAB.addEventListener("click", () => {
    state.a = null;
    state.b = null;
    showToast("A-B 반복 해제");
  });

  e.sleep.addEventListener("change", () => setSleepTimer(e.sleep.value));
  e.pip.addEventListener("click", togglePiP);

  e.srt.addEventListener("change", (event) => {
    const file = event.target.files && event.target.files[0];
    if (file) loadSRT(file);
    event.target.value = "";
  });

  e.subMinus.addEventListener("click", () => adjustSubtitleDelay(-0.1));
  e.subPlus.addEventListener("click", () => adjustSubtitleDelay(0.1));

  e.subReset.addEventListener("click", () => {
    state.subtitleDelay = 0;
    e.subReset.textContent = "0.0s";
    updateSubtitle();
  });

  e.subSmall.addEventListener("click", () => setSubtitleSize(state.subtitleSize - 10));
  e.subLarge.addEventListener("click", () => setSubtitleSize(state.subtitleSize + 10));
  e.subSize.addEventListener("click", () => setSubtitleSize(100));
  e.subPos.addEventListener("change", () => setSubtitlePosition(e.subPos.value));

  e.repeat.addEventListener("click", cycleRepeat);
  e.shuffle.addEventListener("click", toggleShuffle);

  e.video.addEventListener("timeupdate", updateTimeline);
  e.video.addEventListener("play", updatePlayButton);

  e.video.addEventListener("pause", () => {
    updatePlayButton();
    persistResume(true);
  });

  e.video.addEventListener("durationchange", () => {
    e.dur.textContent = formatTime(e.video.duration);
    e.seek.max = String(e.video.duration || 1);
  });

  e.video.addEventListener("ended", () => {
    persistResume(true);
    const item = state.items[state.index];

    if (item) localStorage.removeItem(K.resume + fingerprint(item.file));

    if (state.sleepAtEnd) {
      state.sleepAtEnd = false;
      e.sleep.value = "off";
      showToast("현재 영상 끝에서 멈췄어.");
      return;
    }

    next(true);
  });

  e.video.addEventListener("error", () => {
    showToast(
      "파일 확장자는 지원 대상이지만, 영상 내부 인코딩 방식이 iPhone Web 재생과 맞지 않아.",
      3200
    );
  });

  function isPiPActive() {
    return Boolean(
      document.pictureInPictureElement ||
      (
        e.video.webkitPresentationMode &&
        e.video.webkitPresentationMode === "picture-in-picture"
      )
    );
  }

  function pauseForBackground() {
    persistResume(true);

    if (!isPiPActive() && !e.video.paused) {
      e.video.pause();
    }
  }

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) pauseForBackground();
  });

  window.addEventListener("pagehide", pauseForBackground);

  window.addEventListener("blur", () => {
    setTimeout(() => {
      if (document.hidden || !document.hasFocus()) {
        pauseForBackground();
      }
    }, 120);
  });

  document.addEventListener("freeze", pauseForBackground);

  window.addEventListener("keydown", (event) => {
    if (event.target.matches("input,select")) return;

    if (event.code === "Space") {
      event.preventDefault();
      e.play.click();
    } else if (event.key === "ArrowLeft") {
      seekBy(-10);
    } else if (event.key === "ArrowRight") {
      seekBy(10);
    } else if (event.key.toLowerCase() === "m") {
      e.mute.click();
    }
  });

  setPlaybackRate(Number(localStorage.getItem(K.rate) || 1), false);
  setFit(localStorage.getItem(K.fit) || "contain", false);
  setSubtitleSize(state.subtitleSize);
  setSubtitlePosition(state.subtitlePosition);
  setupGestures();

  if ("serviceWorker" in navigator) {
    let reloadingForUpdate = false;

    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (reloadingForUpdate) return;
      reloadingForUpdate = true;
      location.reload();
    });

    navigator.serviceWorker.register("./sw.js", { updateViaCache: "none" })
      .then((registration) => {
        registration.update().catch(() => {});

        if (registration.waiting) {
          registration.waiting.postMessage({ type: "SKIP_WAITING" });
        }

        registration.addEventListener("updatefound", () => {
          const worker = registration.installing;
          if (!worker) return;

          worker.addEventListener("statechange", () => {
            if (
              worker.state === "installed" &&
              navigator.serviceWorker.controller
            ) {
              worker.postMessage({ type: "SKIP_WAITING" });
            }
          });
        });
      })
      .catch(() => {});
  }
})();
