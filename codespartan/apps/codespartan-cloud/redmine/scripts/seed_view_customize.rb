# Seed de snippets view_customize: branding CodeSpartan para Redmine.
# Idempotente: elimina/crea por nombre (comments).

# ── Login page ────────────────────────────────────────────────────────────────
login_css = <<~CSS
  /* ===== CodeSpartan · Login branding (view_customize) ===== */
  body.controller-account {
    background:
      radial-gradient(1200px 600px at 85% -10%, rgba(255,126,0,.18), transparent 60%),
      radial-gradient(1000px 500px at -10% 110%, rgba(0,90,220,.22), transparent 55%),
      linear-gradient(160deg, #0b1220 0%, #131c31 50%, #0d1526 100%) !important;
    min-height: 100vh;
  }
  body.controller-account #header,
  body.controller-account #top-menu { background: transparent !important; box-shadow: none !important; }
  body.controller-account #wrapper { background: transparent !important; }
  body.controller-account #main { background: transparent !important; display: flex; justify-content: center; padding-top: 6vh; }
  body.controller-account #content { background: transparent; width: 100%; max-width: 420px; }
  body.controller-account #content > h2 {
    display: flex; align-items: center; justify-content: center; gap: 12px;
    color: #fff !important; font-size: 26px; font-weight: 800; letter-spacing: .5px;
    margin-bottom: 18px; text-shadow: 0 2px 12px rgba(0,0,0,.4);
  }
  body.controller-account #content > h2::before {
    content: ""; width: 38px; height: 38px; border-radius: 9px;
    background: linear-gradient(135deg, #ff7e00, #e8560a);
    box-shadow: 0 4px 18px rgba(255,126,0,.45);
  }
  #login-form {
    background: rgba(255,255,255,.06) !important;
    border: 1px solid rgba(255,255,255,.12) !important;
    border-radius: 16px !important;
    backdrop-filter: blur(14px);
    padding: 28px 26px !important;
    box-shadow: 0 24px 60px rgba(0,0,0,.45);
  }
  #login-form label { color: #dbe3f0 !important; font-weight: 600; }
  #login-form input[type=text], #login-form input[type=password] {
    background: rgba(255,255,255,.08) !important;
    border: 1px solid rgba(255,255,255,.18) !important;
    color: #fff !important; border-radius: 9px !important; padding: 9px 12px !important;
  }
  #login-form input:focus { border-color: #ff7e00 !important; box-shadow: 0 0 0 3px rgba(255,126,0,.22) !important; }
  #login-form input[type=submit] {
    background: linear-gradient(135deg, #ff7e00, #e8560a) !important;
    color: #fff !important; font-weight: 700; border-radius: 9px !important;
    border: none !important; padding: 10px 18px !important; width: 100%;
  }
  #login-form input[type=submit]:hover { filter: brightness(1.08); }
  #login-form a, #login-form .login-links a { color: #9db7dd !important; }
  #login-form .login-links { display: flex; justify-content: space-between; margin-top: 14px; }
  body.controller-account #footer { display: none !important; }
CSS

# ── Global header / app chrome ─────────────────────────────────────────────────
header_css = <<~CSS
  /* ===== CodeSpartan · Header branding (view_customize) ===== */
  #header {
    background: linear-gradient(180deg, #0d1526 0%, #131c31 100%) !important;
    border-bottom: 3px solid #ff7e00 !important;
  }
  #top-menu { background: #0a0f1c !important; }
  #header h1 a { color: #fff !important; font-weight: 800; }
  #header h1 a:hover { color: #ff7e00 !important; }
  #quick-search input { border: 1px solid rgba(255,255,255,.2) !important; border-radius: 7px !important; background: rgba(255,255,255,.08) !important; color: #fff !important; }
  #header .drdn { color: #c8d4e8 !important; }
  .tab-content, .ui-widget-content { border-radius: 10px; }
CSS

# ── Kanban / dashboard (redmine_dashboard) ─────────────────────────────────────
kanban_css = <<~CSS
  /* ===== CodeSpartan · Kanban styling (view_customize) ===== */
  .dashboard, .taskboard { gap: 14px !important; }
  .dashboard .column, .taskboard .column {
    background: rgba(13,21,38,.5) !important;
    border: 1px solid rgba(255,255,255,.08) !important;
    border-radius: 12px !important;
  }
  .dashboard .column-head, .taskboard .column-head {
    background: rgba(255,126,0,.12) !important;
    color: #ff9a3d !important; border-radius: 10px 10px 0 0 !important;
    font-weight: 700;
  }
  .dashboard .card, .taskboard .card {
    background: #fff !important; border-radius: 9px !important;
    border-left: 3px solid #ff7e00 !important;
    box-shadow: 0 2px 8px rgba(0,0,0,.18);
    transition: transform .12s ease, box-shadow .12s ease;
  }
  .dashboard .card:hover, .taskboard .card:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(0,0,0,.25); }
  .dashboard .card.ui-sortable-helper, .taskboard .card.ui-sortable-helper { transform: rotate(2deg); }
CSS

def upsert(name, type, position, path, code, project = "")
  ViewCustomize.where("comments = ?", name).destroy_all
  vc = ViewCustomize.new(
    comments: name,
    customize_type: type,
    insertion_position: position,
    path_pattern: path,
    project_pattern: project,
    code: code,
    is_enabled: true,
    is_private: false,
    author: User.where(admin: true).order(:id).first || User.first
  )
  if vc.save
    puts "OK  #{name}"
  else
    puts "ERR #{name}: #{vc.errors.full_messages.join('; ')}"
  end
end

upsert("[Branding] Login page", "css", "html_head", "^/login$|^/account", login_css)
upsert("[Branding] Header global", "css", "html_head", ".*", header_css)
upsert("[Branding] Kanban", "css", "html_head", ".*dashboard.*|.*taskboard.*", kanban_css)
puts "Total: #{ViewCustomize.count}"