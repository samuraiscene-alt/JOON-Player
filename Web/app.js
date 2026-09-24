(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const ids = ["home","player","videos","folderInput","video","stage","dim","subs","gesture","feedback","controls","unlock","openTop","openMain","resumeSession","openFolderMain","add","addFolder","back","name","pos","now","dur","seek","play","rew","fwd","prev","next","lock","mute","full","settingsBtn","queueBtn","settings","queue","resumeToggle","autoNextToggle","rewInterval","fwdInterval","rates","aspectRatio","setA","setB","clearAB","sleep","pip","srt","subLang","subToggle","subMinus","subReset","subPlus","subSmall","subSize","subLarge","subPos","subLineHeight","subOutline","subShadow","subBackground","repeat","shuffle","resetProgress","clearQueue","list","toast","errorModal","errorText","errorOk","errorNext"];
  const e = Object.fromEntries(ids.map((id) => [id, $(id)]));

  const K = {
    rate: "jp.web.rate",
    fit: "jp.web.fit",
    aspectRatio: "jp.web.aspectRatio",
    resumeEnabled: "jp.web.resumeEnabled",
    autoNext: "jp.web.autoNext",
    rewInterval: "jp.web.rewInterval",
    fwdInterval: "jp.web.fwdInterval",
    subSize: "jp.web.subSize",
    subPos: "jp.web.subPos",
    subLineHeight: "jp.web.subLineHeight",
    subOutline: "jp.web.subOutline",
    subShadow: "jp.web.subShadow",
    subBackground: "jp.web.subBackground",
    resume: "jp.web.resume.",
    progress: "jp.web.progress."
  };

  const state = {
    items: [],
    originalOrder: [],
    index: -1,
    objectURL: null,
    repeat: "off",
    shuffle: false,
    resumeEnabled: localStorage.getItem(K.resumeEnabled) !== "0",
    autoNext: localStorage.getItem(K.autoNext) !== "0",
    rewInterval: Number(localStorage.getItem(K.rewInterval) || 10),
    fwdInterval: Number(localStorage.getItem(K.fwdInterval) || 10),
    aspectRatio: localStorage.getItem(K.aspectRatio) || "auto",
    subtitleLineHeight: Number(localStorage.getItem(K.subLineHeight) || 120),
    subtitleOutline: localStorage.getItem(K.subOutline) === "1",
    subtitleShadow: localStorage.getItem(K.subShadow) !== "0",
    subtitleBackground: localStorage.getItem(K.subBackground) === "1",
    locked: false,
    hideTimer: null,
    toastTimer: null,
    feedbackTimer: null,
    a: null,
    b: null,
    sleepTimer: null,
    sleepAtEnd: false,
    cues: [],
    subtitleEnabled: true,
    subtitleDelay: 0,
    subtitleSize: Number(localStorage.getItem(K.subSize) || 100),
    subtitlePosition: localStorage.getItem(K.subPos) || "low",
    brightness: 1,
    gesture: null,
    holdTimer: null,
    temporaryRate: null,
    lastTapAt: 0,
    tapTimer: null,
    lastResumeSave: 0,
    wakeLock: null,
    mediaLoadToken: 0,
    orientationTimer: null,
    pendingLandscapeFullscreen: false,
    orientationLockActive: false
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

  function duplicateKey(file) {
    const relativePath = String(file.webkitRelativePath || "").trim();
    return encodeURIComponent(
      (relativePath || file.name) + "|" + file.size + "|" + file.lastModified
    );
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

  function scrollCurrentPlaylistItem() {
    const current = e.list.querySelector(".item.current");
    if (!current) return;

    requestAnimationFrame(() => {
      current.scrollIntoView({
        block: "center",
        behavior: "smooth"
      });
    });
  }

  function openSheet(sheet) {
    closeSheets();
    sheet.hidden = false;
    showControls(true);

    if (sheet === e.queue) scrollCurrentPlaylistItem();
  }

  function revokeObjectURL() {
    if (!state.objectURL) return;
    URL.revokeObjectURL(state.objectURL);
    state.objectURL = null;
  }

  function fileStem(name) {
    return String(name || "").replace(/\.[^.]+$/, "").trim().toLowerCase();
  }

  function seasonEpisode(name) {
    const stem = fileStem(name);

    const compact = stem.match(/(?:^|[^a-z0-9])s\s*0*(\d{1,2})\s*e\s*0*(\d{1,4})(?=$|[^0-9])/i);
    if (compact) {
      return { season: Number(compact[1]), episode: Number(compact[2]) };
    }

    const korean = stem.match(/(?:시즌|season)\s*0*(\d{1,2}).*?0*(\d{1,4})\s*(?:화|회)/i);
    if (korean) {
      return { season: Number(korean[1]), episode: Number(korean[2]) };
    }

    return null;
  }

  function episodeNumber(name) {
    const season = seasonEpisode(name);
    if (season) return season.episode;

    const stem = fileStem(name);

    const labeled = stem.match(/(?:^|[\s._-])(?:ep(?:isode)?|e)\s*0*(\d{1,4})(?=$|[^0-9])/i);
    if (labeled) return Number(labeled[1]);

    const korean = stem.match(/0*(\d{1,4})\s*(?:화|회)(?=$|[^가-힣a-z0-9])/i);
    if (korean) return Number(korean[1]);

    return null;
  }

  function stripSubtitleLanguage(stem) {
    return String(stem || "").replace(
      /(?:[\s._-]+)(?:ko|kor|kr|korean|한국어|en|eng|english|영어|ja|jpn|jp|japanese|일본어|zh|zho|chi|chinese|중국어)$/i,
      ""
    );
  }

  function subtitleLanguage(file) {
    const stem = fileStem(file && file.name);
    const match = stem.match(
      /(?:^|[\s._-])(ko|kor|kr|korean|한국어|en|eng|english|영어|ja|jpn|jp|japanese|일본어|zh|zho|chi|chinese|중국어)$/i
    );
    const token = match ? match[1].toLowerCase() : "";

    if (/^(ko|kor|kr|korean|한국어)$/i.test(token)) return { code: "ko", label: "한국어" };
    if (/^(en|eng|english|영어)$/i.test(token)) return { code: "en", label: "English" };
    if (/^(ja|jpn|jp|japanese|일본어)$/i.test(token)) return { code: "ja", label: "日本語" };
    if (/^(zh|zho|chi|chinese|중국어)$/i.test(token)) return { code: "zh", label: "中文" };
    return { code: "und", label: "기타" };
  }

  function preferredSubtitle(files) {
    const list = Array.from(files || []);
    return (
      list.find((file) => subtitleLanguage(file).code === "ko") ||
      list.find((file) => subtitleLanguage(file).code === "und") ||
      list.find((file) => subtitleLanguage(file).code === "en") ||
      list.find((file) => subtitleLanguage(file).code === "ja") ||
      list[0] ||
      null
    );
  }

  function seriesTitle(name) {
    return stripSubtitleLanguage(fileStem(name))
      .replace(/(?:^|[^a-z0-9])s\s*0*\d{1,2}\s*e\s*0*\d{1,4}(?=$|[^0-9])/gi, " ")
      .replace(/(?:시즌|season)\s*0*\d{1,2}/gi, " ")
      .replace(/(?:^|[\s._-])(?:ep(?:isode)?|e)\s*0*\d{1,4}(?=$|[^0-9])/gi, " ")
      .replace(/0*\d{1,4}\s*(?:화|회)(?=$|[^가-힣a-z0-9])/gi, " ")
      .replace(/[\[\](){}._-]+/g, " ")
      .replace(/\s+/g, "")
      .trim();
  }

  function titleSimilarity(a, b) {
    if (!a || !b) return 0;
    if (a === b) return 1;
    if (a.includes(b) || b.includes(a)) {
      return Math.min(a.length, b.length) / Math.max(a.length, b.length);
    }

    const bigrams = (value) => {
      if (value.length < 2) return [value];
      const result = [];
      for (let i = 0; i < value.length - 1; i += 1) result.push(value.slice(i, i + 2));
      return result;
    };

    const aa = bigrams(a);
    const bb = bigrams(b);
    const remaining = bb.slice();
    let matches = 0;

    aa.forEach((gram) => {
      const index = remaining.indexOf(gram);
      if (index >= 0) {
        matches += 1;
        remaining.splice(index, 1);
      }
    });

    return (2 * matches) / (aa.length + bb.length);
  }

  function findSubtitlesForVideo(videoFile, subtitles) {
    const videoStem = fileStem(videoFile.name);
    const exact = subtitles.filter(
      (file) => stripSubtitleLanguage(fileStem(file.name)) === videoStem
    );
    if (exact.length) return exact;

    const episode = episodeNumber(videoFile.name);
    if (episode === null) return [];

    const videoSeason = seasonEpisode(videoFile.name);
    const videoTitle = seriesTitle(videoFile.name);
    const candidates = subtitles
      .filter((file) => {
        if (episodeNumber(file.name) !== episode) return false;

        const subtitleSeason = seasonEpisode(file.name);
        if (videoSeason && subtitleSeason) {
          return videoSeason.season === subtitleSeason.season;
        }

        return true;
      })
      .map((file) => ({
        file,
        score: titleSimilarity(videoTitle, seriesTitle(file.name))
      }))
      .sort((a, b) => b.score - a.score);

    if (!candidates.length || candidates[0].score < 0.6) return [];

    const minimum = Math.max(0.6, candidates[0].score - 0.08);
    return candidates
      .filter((candidate) => candidate.score >= minimum)
      .map((candidate) => candidate.file);
  }

  function findSubtitleForVideo(videoFile, subtitles) {
    return preferredSubtitle(findSubtitlesForVideo(videoFile, subtitles));
  }

  function subtitleFilesForItem(item) {
    if (!item) return [];
    if (Array.isArray(item.subtitleFiles) && item.subtitleFiles.length) {
      return item.subtitleFiles;
    }
    return item.subtitleFile ? [item.subtitleFile] : [];
  }

  function resolveSubtitleFile(item) {
    const files = subtitleFilesForItem(item);
    const mode = item && item.subtitleMode ? item.subtitleMode : "auto";

    if (mode === "off") return null;

    if (mode.startsWith("file:")) {
      const key = mode.slice(5);
      return files.find((file) => fingerprint(file) === key) || preferredSubtitle(files);
    }

    return preferredSubtitle(files);
  }

  function updateSubtitleLanguageMenu(item) {
    e.subLang.innerHTML = "";

    const auto = document.createElement("option");
    auto.value = "auto";
    auto.textContent = "자동";
    e.subLang.append(auto);

    const files = subtitleFilesForItem(item);
    const labelCounts = new Map();

    files.forEach((file) => {
      const language = subtitleLanguage(file);
      const count = (labelCounts.get(language.label) || 0) + 1;
      labelCounts.set(language.label, count);

      const option = document.createElement("option");
      option.value = "file:" + fingerprint(file);
      option.textContent = language.code === "und"
        ? file.name
        : language.label + (count > 1 ? " " + String(count) : "");
      e.subLang.append(option);
    });

    const off = document.createElement("option");
    off.value = "off";
    off.textContent = "끔";
    e.subLang.append(off);

    const mode = item && item.subtitleMode ? item.subtitleMode : "auto";
    e.subLang.value = Array.from(e.subLang.options).some((option) => option.value === mode)
      ? mode
      : "auto";
    e.subLang.disabled = !files.length;
  }

  function activateSubtitleMode(item, mode, automatic) {
    if (!item) return;

    item.subtitleMode = mode;
    updateSubtitleLanguageMenu(item);

    if (mode === "off") {
      state.subtitleEnabled = false;
      state.cues = [];
      e.subs.textContent = "";
      e.subToggle.checked = false;
      return;
    }

    const file = resolveSubtitleFile(item);
    item.subtitleFile = file;
    state.subtitleEnabled = true;
    e.subToggle.checked = true;

    if (file) {
      loadSRT(file, item.id, automatic);
    } else {
      state.cues = [];
      e.subs.textContent = "";
      if (!automatic) showToast("연결된 자막이 없어.");
    }
  }

  function compareVideoFiles(a, b) {
    const seasonA = seasonEpisode(a.name);
    const seasonB = seasonEpisode(b.name);

    if (seasonA && seasonB) {
      if (seasonA.season !== seasonB.season) {
        return seasonA.season - seasonB.season;
      }
      if (seasonA.episode !== seasonB.episode) {
        return seasonA.episode - seasonB.episode;
      }
    }

    const episodeA = episodeNumber(a.name);
    const episodeB = episodeNumber(b.name);

    if (episodeA !== null && episodeB !== null && episodeA !== episodeB) {
      return episodeA - episodeB;
    }

    if (episodeA !== null && episodeB === null) return -1;
    if (episodeA === null && episodeB !== null) return 1;

    return a.name.localeCompare(b.name, "ko-KR", {
      numeric: true,
      sensitivity: "base"
    });
  }

  function attachSubtitlesToItems(subtitles, items) {
    if (!subtitles.length || !items.length) return 0;

    let matched = 0;
    let currentMatched = null;
    const currentId = state.index >= 0 ? state.items[state.index]?.id : null;

    items.forEach((item) => {
      const found = findSubtitlesForVideo(item.file, subtitles);
      if (!found.length) return;

      const existing = subtitleFilesForItem(item);
      const keys = new Set(existing.map((file) => fingerprint(file)));
      const fresh = found.filter((file) => !keys.has(fingerprint(file)));
      if (!fresh.length) return;

      item.subtitleFiles = [...existing, ...fresh];
      item.subtitleFile = resolveSubtitleFile(item);
      item.subtitleMode = item.subtitleMode || "auto";
      matched += fresh.length;

      if (item.id === currentId) currentMatched = item;
    });

    if (currentMatched) {
      activateSubtitleMode(
        currentMatched,
        currentMatched.subtitleMode || "auto",
        true
      );
    }

    return matched;
  }

  function addFiles(fileList, replace) {
    const selected = Array.from(fileList || []);
    const candidates = selected
      .filter((file) => /\.(mp4|m4v|mov)$/i.test(file.name))
      .sort(compareVideoFiles);
    const subtitles = selected.filter((file) => /\.srt$/i.test(file.name));
    const unsupportedVideos = selected.filter((file) =>
      /\.(mkv|avi|ts|m2ts|webm|flv)$/i.test(file.name)
    );

    if (!candidates.length) {
      if (subtitles.length && state.items.length) {
        const matched = attachSubtitlesToItems(subtitles, state.items);
        if (!matched) showToast("연결할 자막을 찾지 못했어.");
        return;
      }

      showToast(
        unsupportedVideos.length
          ? "현재 Web에서 지원하지 않는 영상 " + String(unsupportedVideos.length) + "개를 제외했어."
          : "동영상 파일을 선택해줘."
      );
      return;
    }

    if (replace) {
      if (state.index >= 0) persistResume(true);
      e.video.pause();
      state.mediaLoadToken += 1;
      revokeObjectURL();

      clearTimeout(state.sleepTimer);
      state.sleepTimer = null;
      state.sleepAtEnd = false;
      e.sleep.value = "off";

      state.items = [];
      state.originalOrder = [];
      state.index = -1;
      state.shuffle = false;
      state.repeat = "off";
      e.shuffle.textContent = "셔플 끔";
      e.repeat.textContent = "반복 끔";
    }

    const existing = new Set(state.items.map((item) => duplicateKey(item.file)));
    const files = candidates.filter((file) => !existing.has(duplicateKey(file)));
    const skipped = candidates.length - files.length;

    if (!files.length) {
      showToast("이미 재생목록에 있는 파일이야.");
      return;
    }

    const added = files.map((file) => {
      const subtitleFiles = findSubtitlesForVideo(file, subtitles);
      return {
        file,
        subtitleFiles,
        subtitleFile: preferredSubtitle(subtitleFiles),
        subtitleMode: "auto",
        id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + "-" + String(Math.random())
      };
    });

    const currentId = state.index >= 0 ? state.items[state.index]?.id : null;
    const existingItems = state.items.slice();
    attachSubtitlesToItems(subtitles, existingItems);

    state.items.push(...added);
    state.items.sort((a, b) => compareVideoFiles(a.file, b.file));
    state.originalOrder = state.items.slice();

    if (state.shuffle) {
      const current = currentId
        ? state.items.find((item) => item.id === currentId)
        : null;
      const rest = state.items.filter((item) => item.id !== (current && current.id));

      for (let i = rest.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1));
        const temp = rest[i];
        rest[i] = rest[j];
        rest[j] = temp;
      }

      state.items = current ? [current, ...rest] : rest;
      state.index = current ? 0 : -1;
    } else if (currentId) {
      state.index = state.items.findIndex((item) => item.id === currentId);
    }

    renderList();
    updateNavigation();

    if (state.index < 0) {
      const firstUnfinished = state.items.findIndex(
        (item) => storedProgress(item) < 0.95
      );
      playIndex(firstUnfinished >= 0 ? firstUnfinished : 0, true);
      if (unsupportedVideos.length) {
        setTimeout(() => {
          showToast(
            "지원하지 않는 영상 " + String(unsupportedVideos.length) + "개 제외",
            2200
          );
        }, 450);
      }
    } else if (skipped || unsupportedVideos.length) {
      showToast(
        (skipped ? "중복 " + String(skipped) + "개 제외" : "") +
        (skipped && unsupportedVideos.length ? " · " : "") +
        (unsupportedVideos.length
          ? "지원 안 됨 " + String(unsupportedVideos.length) + "개 제외"
          : "")
      );
    }
  }

  function playIndex(index, allowResume) {
    if (!state.items.length) return;

    state.index = clamp(index, 0, state.items.length - 1);
    const item = state.items[state.index];
    const loadToken = ++state.mediaLoadToken;

    revokeObjectURL();
    state.objectURL = URL.createObjectURL(item.file);
    e.video.src = state.objectURL;
    e.video.load();

    e.name.textContent = item.file.name;
    e.pos.textContent = String(state.index + 1) + " / " + String(state.items.length);
    e.home.hidden = true;
    e.player.hidden = false;
    e.resumeSession.hidden = false;
    document.body.classList.add("player-active");
    requestAnimationFrame(applyAspectRatio);

    state.a = null;
    state.b = null;
    state.cues = [];
    state.subtitleEnabled = true;
    state.subtitleDelay = 0;
    e.subs.textContent = "";
    e.subToggle.checked = true;
    e.subReset.textContent = "0.0s";

    updateSubtitleLanguageMenu(item);
    activateSubtitleMode(item, item.subtitleMode || "auto", true);

    function onLoadedMetadata() {
      e.video.removeEventListener("loadedmetadata", onLoadedMetadata);

      if (
        loadToken !== state.mediaLoadToken ||
        state.items[state.index]?.id !== item.id
      ) {
        return;
      }

      e.seek.max = String(e.video.duration || 1);
      e.dur.textContent = formatTime(e.video.duration);

      if (state.resumeEnabled && allowResume !== false) {
        const stored = Number(localStorage.getItem(K.resume + fingerprint(item.file)) || 0);
        if (stored >= 10 && Number.isFinite(e.video.duration) && e.video.duration - stored >= 30) {
          e.video.currentTime = stored;
        }
      }

      e.video.play().catch(() => {});
      scheduleHide();
    }

    e.video.addEventListener("loadedmetadata", onLoadedMetadata);
    renderList();
    updateNavigation();
  }

  function storedProgress(item) {
    return clamp(
      Number(localStorage.getItem(K.progress + fingerprint(item.file)) || 0),
      0,
      1
    );
  }

  function updatePlaylistProgress(item, ratio) {
    if (!item) return;
    const index = state.items.findIndex((entry) => entry.id === item.id);
    if (index < 0) return;

    const fill = e.list.querySelector(
      '[data-index="' + String(index) + '"] .watch-progress-fill'
    );
    if (fill) fill.style.width = String(clamp(ratio, 0, 1) * 100) + "%";
  }

  function renderList() {
    e.list.innerHTML = "";

    state.items.forEach((item, index) => {
      const li = document.createElement("li");
      li.className = "item" + (index === state.index ? " current" : "");
      li.dataset.index = String(index);

      const main = document.createElement("button");
      main.innerHTML =
        '<span class="item-title-row"><strong></strong><span class="watch-progress" aria-hidden="true"><span class="watch-progress-fill"></span></span></span><small></small>';
      main.querySelector("strong").textContent = item.file.name;
      main.querySelector("small").textContent =
        (item.file.size / 1048576).toFixed(item.file.size > 104857600 ? 0 : 1) + " MB";
      main.querySelector(".watch-progress-fill").style.width =
        String(storedProgress(item) * 100) + "%";
      main.addEventListener("click", () => {
        if (index === state.index) {
          closeSheets();
          showControls(true);
          return;
        }

        persistResume(true);
        playIndex(index, true);
        closeSheets();
      });

      const remove = document.createElement("button");
      remove.textContent = "삭제";
      remove.addEventListener("click", () => removeItem(index));

      li.append(main, remove);
      e.list.append(li);
    });

    if (!e.queue.hidden) scrollCurrentPlaylistItem();
  }

  function removeItem(index) {
    const removingCurrent = index === state.index;

    if (removingCurrent) {
      persistResume(true);
    }

    state.items.splice(index, 1);
    state.originalOrder = state.originalOrder.filter((item) =>
      state.items.some((current) => current.id === item.id)
    );

    if (!state.items.length) {
      e.video.pause();
      setWebFullscreen(false);
      if (state.locked) setLocked(false);
      revokeObjectURL();
      state.index = -1;
      e.video.removeAttribute("src");
      e.video.load();
      e.subs.textContent = "";
      e.player.hidden = true;
      e.home.hidden = false;
      e.resumeSession.hidden = true;
      document.body.classList.remove("player-active");
      closeSheets();
      updateNavigation();
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
    if (!fromEnded) persistResume(true);

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

    if (fromEnded) {
      openSheet(e.queue);
      return;
    }

  }

  function previous() {
    persistResume(true);

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

  function viewportSize() {
    const viewport = window.visualViewport;
    return {
      width: Math.round((viewport && viewport.width) || window.innerWidth || 0),
      height: Math.round((viewport && viewport.height) || window.innerHeight || 0)
    };
  }

  function isPortrait() {
    const size = viewportSize();
    return size.height >= size.width;
  }

  function syncFullscreenViewport() {
    if (!e.stage.classList.contains("web-fullscreen")) {
      e.stage.style.removeProperty("--fullscreen-width");
      e.stage.style.removeProperty("--fullscreen-height");
      return;
    }

    const size = viewportSize();
    if (!size.width || !size.height) return;

    e.stage.style.setProperty("--fullscreen-width", size.width + "px");
    e.stage.style.setProperty("--fullscreen-height", size.height + "px");
  }

  function setFit(value, persist) {
    const requested = value || "contain";
    const effective = isPortrait() ? "contain" : requested;

    e.stage.dataset.fit = effective;
    if (persist !== false) localStorage.setItem(K.fit, requested);

    requestAnimationFrame(applyAspectRatio);
  }

  function aspectRatioNumber(value) {
    if (value === "16:9") return 16 / 9;
    if (value === "4:3") return 4 / 3;
    if (value === "21:9") return 21 / 9;
    if (value === "2.35:1") return 2.35;
    return null;
  }

  function applyAspectRatio() {
    const ratio = aspectRatioNumber(state.aspectRatio);
    const fit = e.stage.dataset.fit || "contain";

    if (!ratio || fit !== "contain") {
      e.stage.dataset.aspectActive = "0";
      e.video.style.position = "";
      e.video.style.left = "";
      e.video.style.top = "";
      e.video.style.transform = "";
      e.video.style.width = "";
      e.video.style.height = "";
      return;
    }

    const rect = e.stage.getBoundingClientRect();
    if (!rect.width || !rect.height) return;

    let width = rect.width;
    let height = width / ratio;

    if (height > rect.height) {
      height = rect.height;
      width = height * ratio;
    }

    e.stage.dataset.aspectActive = "1";
    e.video.style.position = "absolute";
    e.video.style.left = "50%";
    e.video.style.top = "50%";
    e.video.style.transform = "translate(-50%, -50%)";
    e.video.style.width = width + "px";
    e.video.style.height = height + "px";
  }

  function setAspectRatio(value, persist) {
    state.aspectRatio = value || "auto";
    e.aspectRatio.value = state.aspectRatio;

    if (persist !== false) {
      localStorage.setItem(K.aspectRatio, state.aspectRatio);
    }

    requestAnimationFrame(applyAspectRatio);
  }

  function persistResume(force) {
    const item = state.items[state.index];
    if (!item || !Number.isFinite(e.video.duration) || e.video.duration <= 0) return;

    const current = e.video.currentTime;
    const remaining = e.video.duration - current;
    const ratio = clamp(current / e.video.duration, 0, 1);

    updatePlaylistProgress(item, ratio);

    const now = Date.now();
    if (!force && now - state.lastResumeSave < 5000) return;
    state.lastResumeSave = now;

    const resumeKey = K.resume + fingerprint(item.file);
    const progressKey = K.progress + fingerprint(item.file);

    if (current >= 1) localStorage.setItem(progressKey, String(ratio));
    else localStorage.removeItem(progressKey);

    if (state.resumeEnabled && current >= 10 && remaining >= 30) {
      localStorage.setItem(resumeKey, String(current));
    } else {
      localStorage.removeItem(resumeKey);
    }
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

  async function requestWakeLock() {
    if (!("wakeLock" in navigator) || document.hidden || e.video.paused) return;

    try {
      if (!state.wakeLock) {
        state.wakeLock = await navigator.wakeLock.request("screen");
        state.wakeLock.addEventListener("release", () => {
          state.wakeLock = null;
        });
      }
    } catch {
      state.wakeLock = null;
    }
  }

  async function releaseWakeLock() {
    if (!state.wakeLock) return;

    try {
      await state.wakeLock.release();
    } catch {
      // Ignore release errors; the browser may have already released it.
    } finally {
      state.wakeLock = null;
    }
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
      return;
    }

    if (state.a === null) state.a = 0;
    state.b = Math.max(e.video.currentTime, state.a + 0.2);
  }

  function setSleepTimer(value) {
    clearTimeout(state.sleepTimer);
    state.sleepTimer = null;
    state.sleepAtEnd = false;

    if (value === "off") return;

    if (value === "end") {
      state.sleepAtEnd = true;
      return;
    }

    const minutes = Number(value);
    state.sleepTimer = setTimeout(() => {
      e.video.pause();
      e.sleep.value = "off";
    }, minutes * 60000);

  }

  async function readSubtitleText(file) {
    const bytes = new Uint8Array(await file.arrayBuffer());

    if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
      return new TextDecoder("utf-8").decode(bytes.subarray(3));
    }

    if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
      return new TextDecoder("utf-16le").decode(bytes.subarray(2));
    }

    if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
      return new TextDecoder("utf-16be").decode(bytes.subarray(2));
    }

    try {
      return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    } catch {
      try {
        return new TextDecoder("euc-kr", { fatal: true }).decode(bytes);
      } catch {
        return new TextDecoder("utf-8").decode(bytes);
      }
    }
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

  async function loadSRT(file, targetId, automatic) {
    try {
      const cues = parseSRT(await readSubtitleText(file));
      if (targetId && state.items[state.index]?.id !== targetId) return;

      if (!cues.length) {
        showToast("자막 내용을 읽지 못했어.");
        return;
      }

      state.cues = cues;
      state.subtitleDelay = 0;
      e.subReset.textContent = "0.0s";

    } catch {
      showToast("자막 파일을 읽지 못했어.");
    }
  }

  function updateSubtitle() {
    if (!state.subtitleEnabled) {
      e.subs.textContent = "";
      return;
    }

    const t = e.video.currentTime - state.subtitleDelay;
    const cue = state.cues.find((item) => t >= item.start && t <= item.end);
    e.subs.textContent = cue ? cue.text : "";
  }

  function toggleSubtitleVisibility() {
    const item = state.items[state.index];
    const enabled = Boolean(e.subToggle.checked);

    if (enabled && !state.cues.length) {
      if (item && subtitleFilesForItem(item).length) {
        activateSubtitleMode(item, item.subtitleMode === "off" ? "auto" : (item.subtitleMode || "auto"), false);
        return;
      }

      e.subToggle.checked = false;
      state.subtitleEnabled = false;
      showToast("연결된 자막이 없어.");
      return;
    }

    state.subtitleEnabled = enabled;
    updateSubtitle();
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

  function setSkipIntervals() {
    state.rewInterval = Number(e.rewInterval.value) || 10;
    state.fwdInterval = Number(e.fwdInterval.value) || 10;
    localStorage.setItem(K.rewInterval, String(state.rewInterval));
    localStorage.setItem(K.fwdInterval, String(state.fwdInterval));
    e.rew.textContent = "−" + String(state.rewInterval);
    e.fwd.textContent = "+" + String(state.fwdInterval);
    e.rew.setAttribute("aria-label", String(state.rewInterval) + "초 뒤로");
    e.fwd.setAttribute("aria-label", String(state.fwdInterval) + "초 앞으로");
  }

  function applySubtitleStyle() {
    e.subs.style.lineHeight = String(state.subtitleLineHeight / 100);
    e.subs.dataset.outline = state.subtitleOutline ? "1" : "0";
    e.subs.dataset.shadow = state.subtitleShadow ? "1" : "0";
    e.subs.dataset.background = state.subtitleBackground ? "1" : "0";

    e.subLineHeight.value = String(state.subtitleLineHeight);
    e.subOutline.checked = state.subtitleOutline;
    e.subShadow.checked = state.subtitleShadow;
    e.subBackground.checked = state.subtitleBackground;
  }

  function saveSubtitleStyle() {
    state.subtitleLineHeight = Number(e.subLineHeight.value) || 120;
    state.subtitleOutline = Boolean(e.subOutline.checked);
    state.subtitleShadow = Boolean(e.subShadow.checked);
    state.subtitleBackground = Boolean(e.subBackground.checked);

    localStorage.setItem(K.subLineHeight, String(state.subtitleLineHeight));
    localStorage.setItem(K.subOutline, state.subtitleOutline ? "1" : "0");
    localStorage.setItem(K.subShadow, state.subtitleShadow ? "1" : "0");
    localStorage.setItem(K.subBackground, state.subtitleBackground ? "1" : "0");

    applySubtitleStyle();
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

  async function tryLockLandscape() {
    if (!screen.orientation || !screen.orientation.lock) return false;

    try {
      await screen.orientation.lock("landscape");
      state.orientationLockActive = true;
      return true;
    } catch {
      state.orientationLockActive = false;
      return false;
    }
  }

  function unlockOrientation() {
    if (!screen.orientation || !screen.orientation.unlock) {
      state.orientationLockActive = false;
      return;
    }

    try {
      screen.orientation.unlock();
    } catch {}

    state.orientationLockActive = false;
  }

  function setWebFullscreen(value, keepPending) {
    const enabled = Boolean(value);

    if (!enabled && !keepPending) {
      state.pendingLandscapeFullscreen = false;
    }

    e.stage.classList.toggle("web-fullscreen", enabled);
    document.body.classList.toggle("player-fullscreen", enabled);
    e.full.setAttribute("aria-label", enabled ? "전체화면 종료" : "전체화면");
    showControls(true);
    scheduleHide();
    syncFullscreenViewport();
    requestAnimationFrame(() => {
      syncFullscreenViewport();
      applyAspectRatio();
    });
    setTimeout(() => {
      syncFullscreenViewport();
      applyAspectRatio();
    }, 320);

    if (!enabled) unlockOrientation();
  }

  async function enterLandscapeFullscreen() {
    setFit(localStorage.getItem(K.fit) || "contain", false);

    if (isPortrait()) {
      state.pendingLandscapeFullscreen = true;

      const locked = await tryLockLandscape();
      if (locked && !isPortrait()) {
        state.pendingLandscapeFullscreen = false;
        setWebFullscreen(true);
        return;
      }

      setWebFullscreen(false, true);
      setFit("contain", false);
      return;
    }

    state.pendingLandscapeFullscreen = false;
    setWebFullscreen(true);
    tryLockLandscape();
  }

  function toggleFullscreen() {
    if (e.stage.classList.contains("web-fullscreen")) {
      setWebFullscreen(false);
      return;
    }

    enterLandscapeFullscreen();
  }

  function handlePlayerOrientationChange() {
    const portrait = isPortrait();

    if (portrait) {
      setFit("contain", false);

      if (e.stage.classList.contains("web-fullscreen")) {
        state.pendingLandscapeFullscreen = true;
        setWebFullscreen(false, true);
      } else {
        syncFullscreenViewport();
        requestAnimationFrame(applyAspectRatio);
      }
      return;
    }

    setFit(localStorage.getItem(K.fit) || "contain", false);

    if (state.pendingLandscapeFullscreen && state.items.length) {
      state.pendingLandscapeFullscreen = false;
      setWebFullscreen(true);
      tryLockLandscape();
    } else {
      syncFullscreenViewport();
      requestAnimationFrame(applyAspectRatio);
    }
  }

  function scheduleOrientationSync(delay) {
    clearTimeout(state.orientationTimer);
    state.orientationTimer = setTimeout(() => {
      handlePlayerOrientationChange();
      setTimeout(() => {
        syncFullscreenViewport();
        applyAspectRatio();
      }, 180);
    }, delay || 260);
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
        : "현재 영상 반복";

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

  function showLockedIndicator() {
    if (!state.locked) return;
    clearTimeout(state.lockHintTimer);
    e.unlock.hidden = false;
    state.lockHintTimer = setTimeout(() => {
      if (state.locked) e.unlock.hidden = true;
    }, 3000);
  }

  function setLocked(value) {
    state.locked = value;
    clearTimeout(state.lockHintTimer);

    if (value) {
      e.controls.classList.add("hide");
      showLockedIndicator();
    } else {
      e.unlock.hidden = true;
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
      if (state.locked) {
        if (event.cancelable) event.preventDefault();
        showLockedIndicator();
        return;
      }
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
        } else if (scale <= 0.88 && pinch.applied !== "contain") {
          setFit("contain", true);
          pinch.applied = "contain";
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
          seekBy(g.lastX < innerWidth / 2 ? -state.rewInterval : state.fwdInterval);
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

  [e.openTop, e.openMain].forEach((button) => {
    button.addEventListener("click", () => {
      e.videos.dataset.replace = "1";
      e.videos.click();
    });
  });

  e.add.addEventListener("click", () => {
    e.videos.dataset.replace = "0";
    e.videos.click();
  });

  e.openFolderMain.addEventListener("click", () => {
    e.folderInput.dataset.replace = "1";
    e.folderInput.click();
  });

  e.addFolder.addEventListener("click", () => {
    e.folderInput.dataset.replace = "0";
    e.folderInput.click();
  });

  e.videos.addEventListener("change", (event) => {
    const replace = e.videos.dataset.replace === "1";
    addFiles(event.target.files, replace);
    event.target.value = "";
    e.videos.dataset.replace = "";
  });

  e.folderInput.addEventListener("change", (event) => {
    const files = event.target.files;
    const replace = e.folderInput.dataset.replace === "1";
    addFiles(files, replace);
    event.target.value = "";
    e.folderInput.dataset.replace = "";
  });

  e.back.addEventListener("click", () => {
    persistResume(true);
    setWebFullscreen(false);
    e.video.pause();
    e.player.hidden = true;
    e.home.hidden = false;
    e.resumeSession.hidden = !state.items.length;
    document.body.classList.remove("player-active");
  });

  e.resumeSession.addEventListener("click", () => {
    if (!state.items.length || state.index < 0) return;

    e.home.hidden = true;
    e.player.hidden = false;
    document.body.classList.add("player-active");
    showControls(true);
    e.video.play().catch(() => showToast("이 파일을 재생할 수 없어."));
  });

  e.play.addEventListener("click", () => {
    if (e.video.paused) e.video.play().catch(() => showToast("이 파일을 재생할 수 없어."));
    else e.video.pause();
  });

  e.rew.addEventListener("click", () => seekBy(-state.rewInterval));
  e.fwd.addEventListener("click", () => seekBy(state.fwdInterval));
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

  e.resumeToggle.addEventListener("change", () => {
    state.resumeEnabled = Boolean(e.resumeToggle.checked);
    localStorage.setItem(K.resumeEnabled, state.resumeEnabled ? "1" : "0");

    if (!state.resumeEnabled) {
      state.items.forEach((item) => {
        localStorage.removeItem(K.resume + fingerprint(item.file));
      });
    }
  });

  e.autoNextToggle.addEventListener("change", () => {
    state.autoNext = Boolean(e.autoNextToggle.checked);
    localStorage.setItem(K.autoNext, state.autoNext ? "1" : "0");
  });

  e.rewInterval.addEventListener("change", setSkipIntervals);
  e.fwdInterval.addEventListener("change", setSkipIntervals);

  e.rates.addEventListener("click", (event) => {
    const button = event.target.closest("[data-rate]");
    if (button) setPlaybackRate(button.dataset.rate, true);
  });

  e.aspectRatio.addEventListener("change", () => {
    setAspectRatio(e.aspectRatio.value, true);
  });

  e.setA.addEventListener("click", () => setAB("a"));
  e.setB.addEventListener("click", () => setAB("b"));

  e.clearAB.addEventListener("click", () => {
    state.a = null;
    state.b = null;
  });

  e.sleep.addEventListener("change", () => setSleepTimer(e.sleep.value));

  e.pip.addEventListener("click", togglePiP);

  e.srt.addEventListener("change", (event) => {
    const files = Array.from(event.target.files || []);
    const item = state.items[state.index];

    if (files.length && item) {
      const existing = subtitleFilesForItem(item);
      const keys = new Set(existing.map((file) => fingerprint(file)));
      const fresh = files.filter((file) => !keys.has(fingerprint(file)));

      item.subtitleFiles = [...existing, ...fresh];
      item.subtitleMode = "auto";
      item.subtitleFile = preferredSubtitle(item.subtitleFiles);
      updateSubtitleLanguageMenu(item);
      activateSubtitleMode(item, "auto", false);
    }

    event.target.value = "";
  });

  e.subLang.addEventListener("change", () => {
    const item = state.items[state.index];
    if (!item) return;
    activateSubtitleMode(item, e.subLang.value, false);
  });

  e.subToggle.addEventListener("change", toggleSubtitleVisibility);
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
  e.subLineHeight.addEventListener("change", saveSubtitleStyle);
  e.subOutline.addEventListener("change", saveSubtitleStyle);
  e.subShadow.addEventListener("change", saveSubtitleStyle);
  e.subBackground.addEventListener("change", saveSubtitleStyle);

  e.repeat.addEventListener("click", cycleRepeat);
  e.shuffle.addEventListener("click", toggleShuffle);

  e.resetProgress.addEventListener("click", () => {
    if (!state.items.length) return;
    if (!window.confirm("현재 재생 목록의 시청기록을 모두 초기화할까?")) return;

    const current = state.items[state.index];
    const wasPlaying = !e.video.paused;

    state.items.forEach((item) => {
      const key = fingerprint(item.file);
      localStorage.removeItem(K.resume + key);
      localStorage.removeItem(K.progress + key);
    });

    state.lastResumeSave = 0;

    if (current && Number.isFinite(e.video.duration)) {
      e.video.currentTime = 0;
      e.seek.value = "0";
      e.now.textContent = "0:00";
    }

    renderList();

    if (wasPlaying) {
      e.video.play().catch(() => {});
    }

  });

  e.clearQueue.addEventListener("click", () => {
    if (!state.items.length) return;
    if (!window.confirm("재생 목록을 모두 비울까?")) return;

    persistResume(true);
    e.video.pause();
    setWebFullscreen(false);
    if (state.locked) setLocked(false);
    revokeObjectURL();

    state.items = [];
    state.originalOrder = [];
    state.index = -1;
    state.a = null;
    state.b = null;
    state.cues = [];

    e.video.removeAttribute("src");
    e.video.load();
    e.subs.textContent = "";
    e.list.innerHTML = "";
    e.player.hidden = true;
    e.home.hidden = false;
    e.resumeSession.hidden = true;
    document.body.classList.remove("player-active");
    closeSheets();
    updateNavigation();
  });

  e.video.addEventListener("timeupdate", updateTimeline);
  e.video.addEventListener("play", () => {
    updatePlayButton();
    requestWakeLock();
  });

  e.video.addEventListener("pause", () => {
    updatePlayButton();
    persistResume(true);
    releaseWakeLock();
  });

  e.video.addEventListener("durationchange", () => {
    e.dur.textContent = formatTime(e.video.duration);
    e.seek.max = String(e.video.duration || 1);
  });

  e.video.addEventListener("ended", () => {
    persistResume(true);
    const item = state.items[state.index];

    if (item) {
      localStorage.removeItem(K.resume + fingerprint(item.file));
      localStorage.setItem(K.progress + fingerprint(item.file), "1");
      renderList();
    }

    if (state.sleepAtEnd) {
      state.sleepAtEnd = false;
      e.sleep.value = "off";
      return;
    }

    if (!state.autoNext && state.repeat !== "one") {
      showControls(true);
      return;
    }

    next(true);
  });

  e.video.addEventListener("error", () => {
    e.video.pause();
    const item = state.items[state.index];
    e.errorText.textContent = item
      ? '"' + item.file.name + '"\n파일이 손상되었거나 iPhone Web에서 지원하지 않는 영상·오디오 코덱일 수 있습니다.'
      : '파일이 손상되었거나 iPhone Web에서 지원하지 않는 영상·오디오 코덱일 수 있습니다.';
    e.errorNext.hidden = !(
      state.items.length > 1 &&
      (state.index < state.items.length - 1 || state.repeat === "all")
    );
    e.errorModal.hidden = false;
  });

  e.errorOk.addEventListener("click", () => {
    e.errorModal.hidden = true;
    showControls(true);
  });

  e.errorNext.addEventListener("click", () => {
    e.errorModal.hidden = true;
    next(false);
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
    if (document.hidden) {
      releaseWakeLock();
      pauseForBackground();
    } else if (!e.video.paused) {
      requestWakeLock();
    }
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

  const orientationQuery = window.matchMedia("(orientation: portrait)");
  if (orientationQuery.addEventListener) {
    orientationQuery.addEventListener("change", () => scheduleOrientationSync(300));
  } else if (orientationQuery.addListener) {
    orientationQuery.addListener(() => scheduleOrientationSync(300));
  }

  window.addEventListener("orientationchange", () => {
    scheduleOrientationSync(360);
  });

  window.addEventListener("resize", () => {
    if (document.body.classList.contains("player-active")) {
      scheduleOrientationSync(280);
    }
  });

  if (window.visualViewport) {
    window.visualViewport.addEventListener("resize", () => {
      if (document.body.classList.contains("player-active")) {
        scheduleOrientationSync(280);
      }
    });
  }

  window.addEventListener("keydown", (event) => {
    if (event.target.matches("input,select")) return;
    if (state.locked) return;

    if (event.code === "Space") {
      event.preventDefault();
      e.play.click();
    } else if (event.key === "ArrowLeft") {
      seekBy(-state.rewInterval);
    } else if (event.key === "ArrowRight") {
      seekBy(state.fwdInterval);
    } else if (event.key.toLowerCase() === "m") {
      e.mute.click();
    }
  });

  e.resumeToggle.checked = state.resumeEnabled;
  e.autoNextToggle.checked = state.autoNext;
  e.rewInterval.value = String(state.rewInterval);
  e.fwdInterval.value = String(state.fwdInterval);
  e.subToggle.checked = state.subtitleEnabled;
  e.aspectRatio.value = state.aspectRatio;
  setSkipIntervals();
  applySubtitleStyle();
  setPlaybackRate(Number(localStorage.getItem(K.rate) || 1), false);
  setFit(localStorage.getItem(K.fit) || "contain", false);
  setAspectRatio(state.aspectRatio, false);
  handlePlayerOrientationChange();
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
