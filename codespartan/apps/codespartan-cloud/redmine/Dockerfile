FROM redmine:6-alpine

USER root

RUN apk add --no-cache git && \
    mkdir -p /home/redmine/.bundle && \
    chmod 1777 /home/redmine/.bundle

WORKDIR /usr/src/redmine

# view_customize: inject custom CSS/JS/HTML per path via Redmine admin UI
# Directory name MUST be "view_customize" (plugin hardcodes this name)
RUN git clone --depth=1 https://github.com/onozaty/redmine-view-customize.git plugins/view_customize

# redmine_discord: send issue notifications to Discord via webhook.
# DISABLED (ago 2026): crashes in a background thread with `each for nil`
# when no webhook is configured yet. Re-enable once a webhook is set up:
#   RUN git clone --depth=1 https://github.com/kory33/redmine_discord.git plugins/redmine_discord
# Setup after deploy: Admin → Custom fields → Projects, List, "Discord Webhooks" → use.

# redmine_dashboard: kanban/drag & drop board with filters per project
# https://github.com/jgraichen/redmine_dashboard
RUN git clone --depth=1 https://github.com/jgraichen/redmine_dashboard.git plugins/redmine_dashboard

# clipboard_image_paste: paste screenshots from clipboard into issues
# https://github.com/peclik/clipboard_image_paste
RUN git clone --depth=1 https://github.com/peclik/clipboard_image_paste.git plugins/clipboard_image_paste

# ── Commercial plugins (add after purchase) ──────────────────────────────────
# at_checklist (€49): https://redmine-plugins.atori.de/en/checklist.html
#   1. Purchase and download at_checklist-x.x.x.zip
#   2. Unzip into plugins/at_checklist/
#   3. Uncomment the line below and rebuild
#   COPY plugins/at_checklist/ plugins/at_checklist/
#
# at_rechnungstellung (€449): https://redmine-plugins.atori.de/en/rechnungstellung.html
#   1. Purchase and download at_rechnungstellung-x.x.x.zip
#   2. Unzip into plugins/at_rechnungstellung/
#   3. Uncomment the lines below and rebuild
#   COPY plugins/at_rechnungstellung/ plugins/at_rechnungstellung/
# ─────────────────────────────────────────────────────────────────────────────

# Email config. The official redmine image IGNORES REDMINE_SMTP_* env vars;
# this ERB file (evaluated at runtime) wires ActionMailer to the Brevo relay.
# Secrets stay in .env → env vars, never baked in the image.
COPY config/configuration.yml.template /usr/src/redmine/config/configuration.yml

# Opale theme (actively maintained fork of PurpleMine2, compatible with
# Redmine 6 / Propshaft). https://github.com/gagnieray/opale
# Redmine 6+ must read custom themes from the top-level themes/ dir; the
# admin entrypoint precompiles them (see deploy-redmine.yml).
RUN git clone --depth=1 https://github.com/gagnieray/opale.git themes/opale

RUN bundle config set without 'development test' && \
    bundle install --no-cache && \
    mkdir -p /usr/src/redmine/public/themes && \
    chmod -R g+w /usr/src/redmine/plugins /usr/src/redmine/files /usr/src/redmine/public/themes && \
    chown -R redmine:redmine /home/redmine /usr/src/redmine

USER redmine
