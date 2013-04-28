var historyValues = [];
var historyCursor = 0;

var session_id = null;

function submitCommand(text, dontClearInput) {
  historyValues.push(text);
  historyCursor = historyValues.length;

  append("<a href=\"#run\">" + escapeHtml(text)+"</a>", "input", escapeHtml("> "),true);
  scrollDown();

  if (!dontClearInput) {
    $("#input").val("");
  }

  jQuery.getJSON("eval", { command: text, session_id: session_id }, function (data) {
    if(data.session_id !== undefined && data.session_id !== session_id) {
      session_id = data.session_id
    }
    if (data.response !== undefined) {
      append(data.response, "response");
    } else if (data.error !== undefined) {
      append(data.error, "error", "", true);
    } else if (data.notification !== undefined) {
      append(data.notification, "notification", "", true);
    } else {
      append("Invalid response from TRY-REDIS server.", "error");
    }

    scrollDown();
  });
};

function append(str, klass, prefix, isHtml) {
  if (prefix === undefined) {
    prefix = "";
  }

  if (!isHtml) {
    prefix = escapeHtml(prefix);
    str = escapeHtml(str);
  }

  var message =
    '<div class="line ' + klass + '">' +
    '<div class="nopad">' +
    '<span class="prompt">' + prefix + '</span>' +
    str +
    '</div></div>';

  $("#log").append(message);
};

function scrollDown() {
  $("#log").attr({ scrollTop: $("#log").attr("scrollHeight") });
};

function escapeHtml(str) {
  str = str.replace(/&/g, "&amp;");
  str = str.replace(/</g, "&lt;");
  str = str.replace(/>/g, "&gt;");
  str = str.replace(/\n/g, "<br>");

  return str;
};

function cursorToEnd(input, text) {
  input.val(text);
  setCaretToPos(input.get(0), text.length);
};

function setSelectionRange(input, selectionStart, selectionEnd) {
  if (input.setSelectionRange) {
    input.focus();
    input.setSelectionRange(selectionStart, selectionEnd);
  } else if (input.createTextRange) {
    var range = input.createTextRange();
    range.collapse(true);
    range.moveEnd('character', selectionEnd);
    range.moveStart('character', selectionStart);
    range.select();
  }
};

function setCaretToPos(input, pos) {
  setSelectionRange(input, pos, pos);
};

$(document).ready(function () {
  $("#input").focus();

  $("#input").keydown(function (event) {
    if (event.keyCode == 13) {
      var text = $("#input").val();

      submitCommand(text);

      return false;
    } else if (event.keyCode == 38) {
      if (historyCursor > 0) {
        var text = historyValues[--historyCursor];
        cursorToEnd($("#input"), escapeHtml(text));
      }

      return false;
    } else if (event.keyCode == 40) {
      if (historyCursor < historyValues.length - 1) {
        var text = historyValues[++historyCursor];
        cursorToEnd($("#input"), escapeHtml(text));
      } else {
        historyCursor = historyValues.length
        $("#input").val("");
      }

      return false;
    }
  });

  $("#toolbar").slideDown(500, function () {
    $("#input").focus();
  });
  $("a[href='#help']").live('click',function () {
    submitCommand("help " + $(this).text());
    return false;
  });
  $("a[href='#run']").live('click',function () {
    submitCommand($(this).text());
    return false;
  });
  /*
  $("a[data-run-command]").live('click',function () {
    submitCommand($.data(this,'run-command'))
    return false;
  });
  $("a[href^='#']").live('click',function () {
    var cmd=unescape($(this).attr('href').substr(1));
    submitCommand(cmd);
    return false;
  });
  */
});
