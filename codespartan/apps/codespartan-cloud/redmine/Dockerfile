FROM redmine:6-alpine

USER root

RUN apk add --no-cache git && \
    mkdir -p /home/redmine/.bundle && \
    chmod 1777 /home/redmine/.bundle

WORKDIR /usr/src/redmine

# view_customize: inject custom CSS/JS/HTML per path via Redmine admin UI
# Directory name MUST be "view_customize" (plugin hardcodes this name)
RUN git clone --depth=1 https://github.com/onozaty/redmine-view-customize.git plugins/view_customize

# redmine_discord: send issue notifications to Discord via webhook
# Setup after deploy: Admin → Custom fields → New field (Projects, List, "Discord Webhooks", multiple values)
# Then per project: Settings → Custom fields → paste webhook URL
RUN git clone --depth=1 https://github.com/kory33/redmine_discord.git plugins/redmine_discord

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

RUN bundle config set without 'development test' && \
    bundle install --no-cache && \
    mkdir -p /usr/src/redmine/public/themes && \
    chmod -R g+w /usr/src/redmine/plugins /usr/src/redmine/files /usr/src/redmine/public/themes && \
    chown -R redmine:redmine /home/redmine /usr/src/redmine

USER redmine
