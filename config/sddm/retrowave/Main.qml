import QtQuick 2.0
import SddmComponents 2.0
import "./components"

Rectangle {
  id: root

  property color bg          : "#0d0f1a"
  property color surface     : "#1e2060"
  property color coral       : "#e8505b"
  property color purple      : "#9b6eb5"
  property color fg          : "#c8cae8"
  property color fg_dim      : "#8890b8"
  property color success     : "#06afc7"
  property color failure     : "#ff3fa4"

  readonly property int unit : 64

  LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
  LayoutMirroring.childrenInherit: true

  TextConstants { id: textConstants }

  function loadTheme() {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", "theme.json")
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        try {
          var t = JSON.parse(xhr.responseText).colors
          bg      = "#" + t.bg_dark
          surface = "#" + t.bg
          coral   = "#" + t.coral
          purple  = "#" + t.purple
          fg      = "#" + t.fg
          fg_dim  = "#" + t.fg_dim
          success = "#" + t.cyan
          failure = "#" + t.error
        } catch (e) {
          console.log("theme.json read failed, using built-in fallback colors: " + e)
        }
      }
    }
    xhr.send()
  }

  Connections {
    target: sddm
    onLoginSucceeded: {
      prompt_txt.color = success
      prompt_txt.text  = textConstants.loginSucceeded
    }
    onLoginFailed: {
      prompt_txt.color = failure
      prompt_txt.text  = textConstants.loginFailed
      anim_failure.start()
    }
  }

  signal tryLogin()
  onTryLogin: {
    sddm.login(username_field.text, password_field.text, session_box.index)
  }

  Image {
    anchors.fill: parent
    source: "wallpaper.png"
    fillMode: Image.PreserveAspectCrop
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.15
  }

  Rectangle {
    id: login_box
    width:  unit * 6
    height: unit * 5.5
    anchors.right: parent.right
    anchors.rightMargin: parent.width * 0.08
    anchors.verticalCenter: parent.verticalCenter

    color  : Qt.rgba(0.05, 0.06, 0.10, 0.88)
    radius : 4
    border.color: coral
    border.width: 1

    Text {
      id: user_label
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.margins: 16
      text: textConstants.userName
      color: fg_dim
      font.family: "Departure Mono"
      font.pixelSize: 14
    }

    TextBox {
      id: username_field
      anchors.top: user_label.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 16
      height: unit * 0.75

      color      : Qt.rgba(0.08, 0.09, 0.16, 0.9)
      borderColor: Qt.rgba(0.18, 0.20, 0.50, 0.8)
      focusColor : coral
      hoverColor : purple
      textColor  : fg

      font.family   : "Departure Mono"
      font.pixelSize: 16

      KeyNavigation.tab: password_field
    }

    Text {
      id: pass_label
      anchors.top: username_field.bottom
      anchors.left: parent.left
      anchors.margins: 16
      text: textConstants.password
      color: fg_dim
      font.family: "Departure Mono"
      font.pixelSize: 14
    }

    PasswordBox {
      id: password_field
      anchors.top: pass_label.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 16
      height: unit * 0.75

      color      : Qt.rgba(0.08, 0.09, 0.16, 0.9)
      borderColor: Qt.rgba(0.18, 0.20, 0.50, 0.8)
      focusColor : coral
      hoverColor : purple
      textColor  : fg

      image: "images/ic_warning_white_24px.svg"
      tooltipEnabled: true
      tooltipText: textConstants.capslockWarning
      tooltipFG: fg
      tooltipBG: surface

      font.family   : "Departure Mono"
      font.pixelSize: 16

      KeyNavigation.tab: login_btn

      Keys.onPressed: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.tryLogin()
          event.accepted = true
        }
      }
    }

    Button {
      id: login_btn
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 16
      height: unit * 0.75

      text     : textConstants.login
      color    : coral
      textColor: "#0d0f1a"

      borderColor : coral
      pressedColor: purple
      activeColor : coral

      font.family   : "Departure Mono"
      font.pixelSize: 16
      font.weight   : Font.DemiBold

      KeyNavigation.tab: session_box
      KeyNavigation.backtab: password_field

      onClicked: root.tryLogin()

      Keys.onPressed: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.tryLogin()
          event.accepted = true
        }
      }
    }
  }

  ComboBox {
    id: session_box
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.margins: 24
    width: unit * 3
    height: unit * 0.6

    model: sessionModel
    index: sessionModel.lastIndex

    color      : Qt.rgba(0.05, 0.06, 0.10, 0.85)
    borderColor: Qt.rgba(0.18, 0.20, 0.50, 0.5)
    focusColor : coral
    hoverColor : purple
    textColor  : fg
    menuColor  : surface

    font.family   : "Departure Mono"
    font.pixelSize: 13

    arrowIcon : "images/ic_arrow_drop_down_white_24px.svg"
    arrowColor: fg_dim

    KeyNavigation.tab: login_btn
  }

  Row {
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.margins: 24
    spacing: 12

    SpButton {
      height: unit * 0.6
      width : unit * 3

      font.family: "Departure Mono"
      label      : textConstants.reboot
      labelColor : fg
      icon       : "images/ic_refresh_white_24px.svg"
      iconColor  : fg_dim
      hoverIconColor  : "#f0a050"
      hoverLabelColor : "#f0a050"

      onClicked: sddm.reboot()
    }

    SpButton {
      height: unit * 0.6
      width : unit * 3

      font.family: "Departure Mono"
      label      : textConstants.shutdown
      labelColor : fg
      icon       : "images/ic_power_settings_new_white_24px.svg"
      iconColor  : fg_dim
      hoverIconColor  : coral
      hoverLabelColor : coral

      onClicked: sddm.powerOff()
    }
  }

  Text {
    id: prompt_txt
    anchors.horizontalCenter: login_box.horizontalCenter
    anchors.bottom: login_box.top
    anchors.bottomMargin: 12
    text : textConstants.prompt
    color: fg_dim
    font.family   : "Departure Mono"
    font.pixelSize: 14

    SequentialAnimation on color {
      id: anim_failure
      running: false
      ColorAnimation { from: failure; to: "transparent"; duration: 1500 }
      onStopped: {
        password_field.text = ""
        prompt_txt.color = fg_dim
        prompt_txt.text  = textConstants.prompt
      }
    }
  }

  Component.onCompleted: {
    loadTheme()
    if (username_field.text === "")
      username_field.focus = true
    else
      password_field.focus = true
  }
}
