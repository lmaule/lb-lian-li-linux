export default {
  header: {
    switchToLight: "Switch to light mode",
    switchToDark: "Switch to dark mode",
    refreshing: "Refreshing…",
    refreshNow: "Refresh now",
    saveFailed: "Save failed: {error}",
    saved: "Changes saved",
  },
  loading: "Connecting to the daemon…",
  unsaved: {
    title: "Unsaved changes.",
    body: "Save to keep them after the app or daemon restarts.",
    shortcut: "Press {keys} to save",
    pageHasChanges: "This page has unsaved changes",
    closeTitle: "Save changes before closing?",
    closeBody: "Unsaved changes are lost if you close without saving. Lighting you previewed can stay on your devices until you save or the daemon restarts.",
    closeDiscard: "Close without saving",
    closeSave: "Save and close",
  },
  pageSubtitle: {
    devices: "Everything Lian Li Linux can see and control",
    lcd: "Screens, media and sensor gauges",
    fans: "Curves and speed for every fan",
    rgb: "Effects and colors for every lighting device",
    aio: "Pump, cooler fans and lighting",
    settings: "Appearance, language, services and daemon",
    installation: "Service, permissions and system setup checks",
  },
  sidebar: {
    connected: "Connected",
    lastSeen: "Last seen: {summary}",
  },
  installationNotice: {
    title: "Check your installation",
    intro: "Some setup checks need attention. You can review these at any time in Installation Health.",
    waitingTitle: "Waiting for daemon",
    waitingBody: "Open Settings to manage services. If the daemon is starting, wait and Recheck.",
    allPass: "These installation checks now pass.",
    later: "Later",
    recheck: "Recheck",
    openGuide: "Open guide",
    reviewChecks: "Review checks",
  },
  updateNotice: {
    title: "Lian Li Linux {version} is available",
    releaseNotes: "View release notes",
  },
  wirelessNotice: {
    transmitterTitle: "Wireless transmitter stopped responding",
    transmitterBody:
      "Unplug the wireless transmitter and plug it back in. Software resets did not restart it. Wireless fans and pumps keep their last speed until it responds.",
    receiverTitle: "Wireless receiver stopped responding",
    receiverBody:
      "Unplug the wireless receiver and plug it back in. Software resets did not restart it. Wireless fans and pumps keep their last speed until it responds.",
  },
  compatibilityNotice: {
    title: "Changes disabled",
  },
  editableName: {
    renameDevice: "Rename this device",
    deviceName: "Device name",
  },
  externalLink: {
    openFailedCopied: "Could not open the link: {error}. The link was copied to the clipboard.",
    openFailed: "Could not open the link: {error}. {url}",
  },
  download: {
    timedOut: "Download timed out. Check your connection and retry",
    tooLarge: "Download exceeds {limit} bytes",
    noBody: "Download body is unavailable",
  },
  config: {
    copiedTemplateChanged: "A copied template changed in another window. Reload and review the import before saving.",
    lcdNotConfirmed: "Copied templates were saved, but LCD settings were not confirmed. Retry Save or reload to inspect settings. {error}",
    previousImportPending: "Save or reload the previous copied selection first.",
  },
};
