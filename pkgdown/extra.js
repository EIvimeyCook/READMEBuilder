// GitHub shows "> [!NOTE]", "> [!IMPORTANT]" etc. in the README as coloured
// callouts, but pkgdown prints the marker as text. Turn those quotes into
// Bootstrap alerts so the README works in both places.
document.addEventListener("DOMContentLoaded", function () {
  var kinds = {
    NOTE: ["Note", "info"],
    TIP: ["Tip", "success"],
    IMPORTANT: ["Important", "primary"],
    WARNING: ["Warning", "warning"],
    CAUTION: ["Caution", "danger"]
  };
  document.querySelectorAll("main blockquote").forEach(function (quote) {
    var first = quote.querySelector("p");
    if (!first) return;
    var match = first.innerHTML.match(/^\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*/);
    if (!match) return;
    var kind = kinds[match[1]];
    first.innerHTML = first.innerHTML.slice(match[0].length);
    var title = document.createElement("p");
    title.className = "gh-alert-title";
    title.textContent = kind[0];
    quote.insertBefore(title, first);
    quote.classList.add("alert", "alert-" + kind[1], "gh-alert");
  });
});
