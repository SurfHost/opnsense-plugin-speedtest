/*
 * Copyright (C) 2024 Deciso B.V.
 * Copyright (C) 2026 SurfHost.nl
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

export default class SpeedtestSurfHost extends BaseTableWidget {
    constructor() {
        super();
        this.tickTimeout = 300;
    }

    getMarkup() {
        let $container = $('<div></div>');
        $container.append(this.createTable('speedtestsurfhost-table', {
            headerPosition: 'left',
        }));
        return $container;
    }

    minmax(v, unit) {
        return $('<span/>')
            .append($('<strong/>').text(`${v.avg} ${unit}`))
            .append(document.createTextNode(` (min ${v.min}, max ${v.max})`));
    }

    async onWidgetTick() {
        const stat = await this.ajaxCall('/api/speedtestsurfhost/service/stat');
        const recent = await this.ajaxCall('/api/speedtestsurfhost/service/recent');

        let $recent = $('<span/>');
        if (!recent || recent.error) {
            $recent.text(recent && recent.error ? recent.error : '');
        } else {
            let $when = $('<span/>').text(recent.date);
            if (typeof recent.link === 'string' && /^https:\/\/[^\s"'<>]+$/.test(recent.link)) {
                $when = $('<a target="_blank" rel="noopener noreferrer"/>').attr('href', recent.link).text(recent.date);
            }
            $recent.append($when).append('<br/>')
                .append($('<strong/>').text(`${this.translations.down} ${recent.download} Mbps`))
                .append(document.createTextNode(
                    ` (${this.translations.up} ${recent.upload} Mbps, ${this.translations.latency} ${recent.latency} ms)`));
        }
        $('#speedtestsurfhost_recent').empty().append($recent);

        if (stat && !stat.error && stat.samples > 0) {
            $('#speedtestsurfhost_latency').empty().append(this.minmax(stat.latency, 'ms'));
            $('#speedtestsurfhost_download').empty().append(this.minmax(stat.download, 'Mbps'));
            $('#speedtestsurfhost_upload').empty().append(this.minmax(stat.upload, 'Mbps'));
        }
    }

    async onMarkupRendered() {
        $(`#${this.id}-title`).html(
            $('<b/>').append($('<a href="/ui/speedtestsurfhost/"/>').text(this.translations.title)));
        let rows = [];
        rows.push([[this.translations.most_recent], $('<span id="speedtestsurfhost_recent">').prop('outerHTML')]);
        rows.push([[this.translations.avg_download], $('<span id="speedtestsurfhost_download">').prop('outerHTML')]);
        rows.push([[this.translations.avg_upload], $('<span id="speedtestsurfhost_upload">').prop('outerHTML')]);
        rows.push([[this.translations.avg_latency], $('<span id="speedtestsurfhost_latency">').prop('outerHTML')]);
        super.updateTable('speedtestsurfhost-table', rows);
    }
}
