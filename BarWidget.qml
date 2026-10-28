import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// Transport controls for cliamp's MPRIS player. The bar shows previous,
// play/pause, and next; hovering the controls pops out the current track.
// The widget hides itself while cliamp is not running.
BarWidget {
  id: root
  moduleName: "io.github.mattwolfgang.simple-cliamp-bar-controls"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p) continue
      var dbusName = String(p.dbusName || "").toLowerCase()
      var identity = String(p.identity || "").toLowerCase()
      if (identity === "cliamp" || /(^|\.)cliamp(\.|$)/.test(dbusName)) return p
    }
    return null
  }

  readonly property bool running: player !== null
  readonly property bool isPlaying: running && !!player.isPlaying
  readonly property string title: running ? String(player.trackTitle || "").trim() : ""
  readonly property string artist: running ? String(player.trackArtist || "").trim() : ""
  readonly property string album: running ? String(player.trackAlbum || "").trim() : ""
  readonly property string artUrl: running && player.trackArtUrl ? player.trackArtUrl : ""
  readonly property bool hasLength: running && player.lengthSupported && player.length > 0
  readonly property real position: running && player.positionSupported ? player.position : 0
  readonly property real progress: hasLength ? Math.max(0, Math.min(1, position / player.length)) : 0

  readonly property bool canPrevious: running && !!player.canGoPrevious
  readonly property bool canNext: running && !!player.canGoNext
  readonly property bool canToggle: running && !!(player.canTogglePlaying || player.canPlay || player.canPause)

  // Shape contract for shell.summon/hide/toggle routing and for the bar's
  // one-popout-at-a-time coordinator.
  property bool popupOpen: false
  readonly property bool opened: popupOpen
  function open() { if (running) popupOpen = true }
  function close() { popupOpen = false }

  function previous() { if (canPrevious) player.previous() }
  function next() { if (canNext) player.next() }
  function playPause() {
    if (!running) return
    if (player.canTogglePlaying) player.togglePlaying()
    else if (player.isPlaying && player.canPause) player.pause()
    else if (!player.isPlaying && player.canPlay) player.play()
  }

  function formatTime(seconds) {
    var total = Math.max(0, Math.floor(seconds || 0))
    var h = Math.floor(total / 3600)
    var m = Math.floor((total % 3600) / 60)
    var s = total % 60
    var ss = s < 10 ? "0" + s : String(s)
    if (h > 0) return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss
    return m + ":" + ss
  }

  visible: running
  implicitWidth: running ? controls.implicitWidth : 0
  implicitHeight: running ? controls.implicitHeight : 0

  onRunningChanged: if (!running) close()

  // Hover over the controls or the card keeps the card open. Opening waits a
  // beat so sweeping the pointer across the bar does not flash it, and
  // closing waits long enough to cross the gap between bar and card.
  readonly property bool hoverActive: widgetHover.hovered || popup.containsMouse
  onHoverActiveChanged: {
    if (hoverActive) {
      closeTimer.stop()
      if (!popupOpen) openTimer.restart()
    } else {
      openTimer.stop()
      closeTimer.restart()
    }
  }

  HoverHandler { id: widgetHover }

  Timer {
    id: openTimer
    interval: 250
    onTriggered: if (root.hoverActive) root.open()
  }

  Timer {
    id: closeTimer
    interval: 300
    onTriggered: if (!root.hoverActive) root.close()
  }

  // MPRIS does not push position updates; poll it only while the card shows
  // a progress bar for a playing track.
  Timer {
    interval: 1000
    repeat: true
    running: root.popupOpen && root.isPlaying && root.hasLength
    onTriggered: root.player.positionChanged()
  }

  Grid {
    id: controls
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 3
    // Transport controls keep previous, play, next in every language,
    // matching their glyphs; media controls are not mirrored.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    BarIconButton {
      bar: root.bar
      text: "󰒮"
      dimmed: !root.canPrevious
      onPressed: function(b) { if (b === Qt.LeftButton) root.previous() }
    }

    BarIconButton {
      bar: root.bar
      text: root.isPlaying ? "󰏤" : "󰐊"
      dimmed: !root.canToggle
      onPressed: function(b) { if (b === Qt.LeftButton) root.playPause() }
    }

    BarIconButton {
      bar: root.bar
      text: "󰒭"
      dimmed: !root.canNext
      onPressed: function(b) { if (b === Qt.LeftButton) root.next() }
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    triggerMode: "hover"
    open: root.popupOpen && root.running
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent)

          SizedImage {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            crop: true
            url: root.artUrl
            visible: url != ""
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: root.artUrl === ""
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            textFormat: Text.PlainText
            text: ("cliamp · " + (root.isPlaying ? strings.t("status.playing")
              : (root.running && root.player.playbackState === MprisPlaybackState.Paused
                ? strings.t("status.paused") : strings.t("status.stopped")))).toUpperCase()
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.title || strings.t("track.unknown")
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.album
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.hasLength

        Rectangle {
          width: parent.width
          height: Style.space(4)
          radius: height / 2
          color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.18)

          Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: parent.radius
            color: root.bar.foreground
          }
        }

        Item {
          width: parent.width
          height: elapsedText.implicitHeight

          Text {
            id: elapsedText
            textFormat: Text.PlainText
            anchors.left: parent.left
            text: root.formatTime(root.position)
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            text: root.hasLength ? root.formatTime(root.player.length) : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: root.running && !root.hasLength && root.title !== ""
        text: strings.t("track.live")
        color: Qt.darker(root.bar.foreground, 1.6)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        width: parent.width
      }
    }
  }
}
