import Foundation

/// Builds the HTML document shown in the Canvas live preview. Pure and testable:
/// HTML is passed through, JavaScript is wrapped in a page that captures console
/// output and errors, and Mermaid diagrams are rendered with a bundled mermaid.js
/// (offline, no network). The WebView itself lives in `CanvasWebView`.
enum CanvasPreview {

    static func isPreviewable(_ language: String) -> Bool {
        ["html", "htm", "javascript", "js", "mermaid"].contains(language.lowercased())
    }

    static func htmlDocument(language: String, source: String) -> String {
        switch language.lowercased() {
        case "html", "htm": return source
        case "mermaid":     return mermaidHTML(source)
        default:            return jsHTML(source)
        }
    }

    /// Neutralise a literal closing script tag so user code can't break out of the
    /// wrapping <script> element.
    static func escapeScript(_ source: String) -> String {
        source.replacingOccurrences(of: "</script>", with: "<\\/script>")
    }

    static func jsHTML(_ source: String) -> String {
        let safe = escapeScript(source)
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body{font-family:-apple-system,system-ui,sans-serif;margin:16px;color:#111;background:#fff}
          #out{white-space:pre-wrap;font-family:ui-monospace,Menlo,monospace;font-size:13px;
               background:#f4f4f5;border-radius:8px;padding:12px;margin-top:12px}
          #out:empty{display:none}
          .err{color:#b91c1c}
        </style></head>
        <body><div id="app"></div><div id="out"></div>
        <script>
        (function(){
          var out=document.getElementById('out');
          function write(s,cls){var d=document.createElement('div');if(cls)d.className=cls;d.textContent=s;out.appendChild(d);}
          ['log','warn','error','info'].forEach(function(k){
            var orig=console[k];
            console[k]=function(){
              var a=Array.prototype.map.call(arguments,function(x){
                try{return typeof x==='object'?JSON.stringify(x):String(x)}catch(e){return String(x)}
              }).join(' ');
              write(a,k==='error'?'err':'');
              if(orig)orig.apply(console,arguments);
            };
          });
          window.onerror=function(m){write('\\u26a0 '+m,'err');return false;};
        })();
        </script>
        <script>
        \(safe)
        </script>
        </body></html>
        """
    }

    /// Bundled mermaid.js, loaded once. Empty string if the resource is missing,
    /// in which case the preview shows a friendly fallback instead of crashing.
    static let mermaidJS: String = {
        guard let url = Bundle.main.url(forResource: "mermaid.min", withExtension: "js"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return s
    }()

    static func mermaidHTML(_ source: String) -> String {
        let safe = escapeScript(source)
        let lib = mermaidJS
        let fallback = lib.isEmpty
            ? "document.getElementById('err').textContent='Mermaid library not bundled.';"
            : "try{mermaid.initialize({startOnLoad:true,theme:'default',securityLevel:'loose'});}catch(e){document.getElementById('err').textContent='Mermaid error: '+e;}"
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body{margin:16px;background:#fff;font-family:-apple-system,system-ui,sans-serif}
          #err{color:#b91c1c;font-size:13px;white-space:pre-wrap}
          .mermaid{display:flex;justify-content:center}
        </style></head>
        <body><pre class="mermaid">
        \(safe)
        </pre><div id="err"></div>
        <script>
        \(lib)
        </script>
        <script>
        \(fallback)
        </script>
        </body></html>
        """
    }
}