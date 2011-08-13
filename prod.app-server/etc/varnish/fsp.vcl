// (lcalitz) Varnish config from Pressflow site, replacing 
// default.vcl.default. Modified by input from Lullabot:
// http://www.lullabot.com/articles/varnish-multiple-web-servers-drupal
//
// This file is under version control at git@github.com:fspadmin/FSP-Tools.git
// Please check in any changes to this file!

backend default {
  .host = "127.0.0.1";
  .port = "8080";
  .connect_timeout = 600s;
  .first_byte_timeout = 600s;
  .between_bytes_timeout = 600s;
}

sub vcl_recv {
  
  // (lcalitz) Don't cache phplist
  if (req.http.host == "phplist.freestateproject.org") {
    return (pass);
  }

  // (lcalitz) Bugfix for Varnish - force POST to use pipe.  Note local 
  // vcl_pipe() to close connection and pipe_timeout in startup 
  // params to hold it open for slo-o-o-o-o-w requests of several minutes.
  if (req.request == "POST") { 
    return (pipe); 
  } 

  if (req.request != "GET" &&
    req.request != "HEAD" &&
    req.request != "PUT" &&
    req.request != "POST" &&
    req.request != "TRACE" &&
    req.request != "OPTIONS" &&
    req.request != "DELETE") {
    /* Non-RFC2616 or CONNECT which is weird. */
     return (pipe);
  }

  if (req.request != "GET" && req.request != "HEAD") {
    /* We only deal with GET and HEAD by default */
    return (pass);
  }

  // (lcalitz) Avoid double caching
  set req.http.host = regsub(req.http.host, "^www\.freestateproject\.org$","freestateproject.org");
  set req.http.host = regsub(req.http.host, "^www\.freestatemovement\.(org|com)$","freestateproject.org");
  set req.http.host = regsub(req.http.host, "^www\.porcfest\.org$","porcfest.com");
  set req.http.host = regsub(req.http.host, "^www\.porcfest\.com$","porcfest.com");
  set req.http.host = regsub(req.http.host, "^porcfest\.org$","porcfest.com");

  // (lcalitz) From Lullabot, always cache these
  if (req.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js|html|htm)(\?[a-z0-9]+)?$") {
    unset req.http.Cookie;
  }
  
  // (lcalitz) Cookies: Use Lullabot's recommendation for Drupal
  if (req.http.host == "freestateproject.org" || 
      req.http.host == "porcfest.com") {
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(__[a-z]+|has_js)=[^;]*", "");

    // (lcalitz) Use Lullabot's config below instead of the above
    // Remove all cookies that Drupal doesn't need to know about. ANY remaining
    // cookie will cause the request to pass-through to Apache. For the most part
    // we always set the NO_CACHE cookie after any POST request, disabling the
    // Varnish cache temporarily. The session cookie allows all authenticated users
    // to pass through as long as they're logged in.
    if (req.http.Cookie) {
      set req.http.Cookie = ";" req.http.Cookie;
      set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
      set req.http.Cookie = regsuball(req.http.Cookie, ";(SESS[a-z0-9]+|NO_CACHE)=", "; \1=");
      set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
      set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");
 
      if (req.http.Cookie == "") {
        // If there are no remaining cookies, remove the cookie header. If there
        // aren't any cookie headers, Varnish's default behavior will be to cache
        // the page.
        unset req.http.Cookie;
      }
      else {
        // If there are any cookies left (a session or NO_CACHE cookie), do not
        // cache the page. Pass it on to Apache directly.
        return (pass);
      }
    }
  }
  else {
    // Remove has_js and Google Analytics cookies.
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(__[a-z]+|__utma_a2a|has_js)=[^;]*", "");

    // To users: if you have additional cookies being set by your system (e.g.
    // from a javascript analytics file or similar) you will need to add VCL
    // at this point to strip these cookies from the req object, otherwise
    // Varnish will not cache the response. This is safe for cookies that your
    // backend (Drupal) doesn't process.
    //
    // Again, the common example is an analytics or other Javascript add-on.
    // You should do this here, before the other cookie stuff, or by adding
    // to the regular-expression above.

    // Remove a ";" prefix, if present.
    set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
    // Remove empty cookies.
    if (req.http.Cookie ~ "^\s*$") {
      unset req.http.Cookie;
    }

    if (req.http.Authorization || req.http.Cookie) {
      // Not cacheable by default
      return (pass);
    }

  // Skip the Varnish cache for install, update, and cron
  //if (req.url ~ "install\.php|update\.php|cron\.php") {
  //  return (pass);
  //}
  
  // (lcalitz) Use Lullabot's instead of the above
  if (req.url ~ "^/status\.php$" ||
    req.url ~ "^/update\.php$" ||
    req.url ~ "^/ooyala/ping$" ||
    req.url ~ "^/admin/build/features" ||
    req.url ~ "^/info/.*$" ||
    req.url ~ "^/flag/.*$" ||
    req.url ~ "^.*/ajax/.*$" ||
    req.url ~ "^.*/ahah/.*$") {
    return (pass);
  }
  
  // (lcalitz) Lullabot recommends this
  # Pipe these paths directly to Apache for streaming.
  if (req.url ~ "^/admin/content/backup_migrate/export") {
    return (pipe);
  }

  // Normalize the Accept-Encoding header
  // as per: http://varnish-cache.org/wiki/FAQ/Compression
  //if (req.http.Accept-Encoding) {
  //  if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
  //    # No point in compressing these
  //    remove req.http.Accept-Encoding;
  //  }
  //  elsif (req.http.Accept-Encoding ~ "gzip") {
  //    set req.http.Accept-Encoding = "gzip";
  //  }
  //  else {
  //    # Unknown or deflate algorithm
  //    remove req.http.Accept-Encoding;
  //  }
  //}
 
  // (lcalitz) Use Lullabot's instead of the above 
  // Handle compression correctly. Different browsers send different
  // "Accept-Encoding" headers, even though they mostly all support the same
  // compression mechanisms. By consolidating these compression headers into
  // a consistent format, we can reduce the size of the cache and get more hits.
  // @see: http:// varnish.projects.linpro.no/wiki/FAQ/Compression
  if (req.http.Accept-Encoding) {
    if (req.http.Accept-Encoding ~ "gzip") {
      // If the browser supports it, we'll use gzip.
      set req.http.Accept-Encoding = "gzip";
    }
    else if (req.http.Accept-Encoding ~ "deflate") {
      // Next, try deflate if it is supported.
      set req.http.Accept-Encoding = "deflate";
    }
    else {
      // Unknown algorithm. Remove it and send unencoded.
      unset req.http.Accept-Encoding;
    }
  }

  // Let's have a little grace
  set req.grace = 30s;

  return (lookup);
}

sub vcl_hash {
  // (lcalitz) Not needed because we pass on all cookies a la Lullabot
  //if (req.http.Cookie) {
  //  set req.hash += req.http.Cookie;
  //}
}

// Strip any cookies before an image/js/css is inserted into cache.
sub vcl_fetch {
  if (req.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js|html|htm)(\?[a-z0-9]+)?$") {
    // For Varnish 2.0 or earlier, replace beresp with obj:
    // unset obj.http.set-cookie;
    unset beresp.http.set-cookie;
  }
}

sub vcl_error {
  // Let's deliver a friendlier error page.
  // You can customize this as you wish.
  set obj.http.Content-Type = "text/html; charset=utf-8";
  synthetic {"
  <?xml version="1.0" encoding="utf-8"?>
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
  <html>
    <head>
      <title>"} obj.status " " obj.response {"</title>
      <style type="text/css">
      #page {width: 400px; padding: 10px; margin: 20px auto; border: 1px solid black; background-color: #FFF;}
      p {margin-left:20px;}
      body {background-color: #DDD; margin: auto;}
      </style>
    </head>
    <body>
    <div id="page">
    <h1>Page Could Not Be Loaded</h1>
    <p>We're very sorry, but the page could not be loaded properly. This should be fixed very soon, and we apologize for any inconvenience.</p>
    <hr />
    <h4>Debug Info:</h4>
    <pre>Status: "} obj.status {"
Response: "} obj.response {"
XID: "} req.xid {"</pre>
      </div>
    </body>
   </html>
  "};
  return(deliver);
}
