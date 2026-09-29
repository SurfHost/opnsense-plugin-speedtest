{#
 # Copyright (c) 2021 Miha Kralj
 # Copyright (c) 2026 SurfHost.nl
 # All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions are met:
 #
 # 1. Redistributions of source code must retain the above copyright notice,
 #    this list of conditions and the following disclaimer.
 #
 # 2. Redistributions in binary form must reproduce the above copyright
 #    notice, this list of conditions and the following disclaimer in the
 #    documentation and/or other materials provided with the distribution.
 #
 # THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 # INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 # AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 # AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 # OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 # POSSIBILITY OF SUCH DAMAGE.
 #}

<script>
    'use strict';

    // only https result links become anchors; everything else is plain text
    function resultLink(url) {
        if (typeof url === 'string' && /^https:\/\/[^\s"'<>]+$/.test(url)) {
            return $('<a target="_blank" rel="noopener noreferrer"/>').attr('href', url).text(url);
        }
        return $('<span/>').text(url || '');
    }

    function minmax(v, unit) {
        return $('<span/>')
            .append($('<b/>').text(v.avg + ' ' + unit))
            .append(document.createTextNode(' (min ' + v.min + ', max ' + v.max + ')'));
    }

    function statReload() {
        ajaxGet('/api/speedtestsurfhost/service/stat', {}, function (s) {
            if (!s || s.error) {
                return;
            }
            $('#stat_samples').text(s.samples + (s.samples ? ' (' + s.period.oldest + ' – ' + s.period.youngest + ')' : ''));
            $('#stat_download').empty().append(minmax(s.download, 'Mbps'));
            $('#stat_upload').empty().append(minmax(s.upload, 'Mbps'));
            $('#stat_latency').empty().append(minmax(s.latency, 'ms'));
        });
    }

    function logReload() {
        ajaxGet('/api/speedtestsurfhost/service/log', {}, function (rows) {
            let $body = $('#log_block').empty();
            if (!Array.isArray(rows)) {
                return;
            }
            rows.forEach(function (r) {
                $body.append($('<tr/>')
                    .append($('<td/>').text(r.date))
                    .append($('<td/>').text(r.serverid))
                    .append($('<td/>').text(r.servername))
                    .append($('<td/>').text(Number(r.download).toFixed(2)))
                    .append($('<td/>').text(Number(r.upload).toFixed(2)))
                    .append($('<td/>').text(Number(r.latency).toFixed(2)))
                    .append($('<td/>').append(resultLink(r.link))));
            });
        });
    }

    // the program the saved settings use; Install and Remove act on that,
    // not on an unsaved choice in the form
    let savedBackend = 'cli';

    function versionReload() {
        ajaxGet('/api/speedtestsurfhost/service/version', {}, function (v) {
            $('#checking').hide();
            if (!v || v.error) {
                $('#program_state').text(v && v.error ? v.error : '');
                return;
            }
            savedBackend = v.backend;
            let name = v.backend === 'ookla' ? 'Ookla speedtest' : 'speedtest-cli';
            $('#program_name').text(name);
            $('#program_state').text(v.message);
            $('#program_state').toggleClass('text-danger', !v.ready);
            $('.canruntests').toggle(v.ready);
            let installed = v.backend === 'ookla' ? v.ookla_installed : v.cli_installed;
            $('#installAct').toggle(!installed);
            $('#removeAct').toggle(installed);
        });
    }

    function busy(id, on) {
        $('#' + id + '_progress').toggleClass('fa fa-spinner fa-pulse', on);
    }

    function showResult(r) {
        $('#test_results').show();
        if (!r || r.error) {
            $('#res_error').text(r && r.error ? r.error : '{{ lang._("No answer") }}').show();
            $('#res_rows').hide();
            return;
        }
        $('#res_error').hide();
        $('#res_rows').show();
        $('#dlspeed').text(r.download + ' Mbps');
        $('#ulspeed').text(r.upload + ' Mbps');
        $('#latency').text(r.latency + ' ms');
        $('#server').text('(' + r.serverid + ') ' + r.servername + ', ' + r.country);
        $('#client').text(r.clientip);
        $('#result').empty().append(resultLink(r.link));
    }

    $(document).ready(function () {
        mapDataToFormUI({'frm_general_settings': '/api/speedtestsurfhost/settings/get'}).done(function () {
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
            versionReload();
        });
        statReload();
        logReload();

        $('#saveAct').click(function () {
            busy('saveAct', true);
            saveFormToEndpoint('/api/speedtestsurfhost/settings/set', 'frm_general_settings', function () {
                ajaxCall('/api/speedtestsurfhost/service/reconfigure', {}, function () {
                    busy('saveAct', false);
                    versionReload();
                });
            }, true, function () {
                busy('saveAct', false);
            });
        });

        $('#installAct').click(function () {
            busy('installAct', true);
            ajaxCall('/api/speedtestsurfhost/service/install', {'backend': savedBackend}, function (r) {
                busy('installAct', false);
                $('#install_msg').text(r && r.message ? r.message : (r && r.error ? r.error : ''))
                    .toggleClass('text-danger', !r || r.status !== 'ok');
                versionReload();
            });
        });

        $('#removeAct').click(function () {
            busy('removeAct', true);
            ajaxCall('/api/speedtestsurfhost/service/install', {'backend': 'remove-' + savedBackend}, function (r) {
                busy('removeAct', false);
                $('#install_msg').text(r && r.message ? r.message : '').removeClass('text-danger');
                versionReload();
            });
        });

        $('#serverlistAct').click(function () {
            busy('serverlistAct', true);
            ajaxGet('/api/speedtestsurfhost/service/serverlist', {}, function (list) {
                busy('serverlistAct', false);
                let $sel = $('#speedlist').empty()
                    .append($('<option/>').val('').text('{{ lang._("default server from the settings") }}'));
                if (Array.isArray(list) && list.length > 0) {
                    list.forEach(function (s) {
                        $sel.append($('<option/>').val(s.id)
                            .text('(' + s.id + ') ' + s.name + ', ' + s.location + (s.country ? ', ' + s.country : '')));
                    });
                } else {
                    $sel.append($('<option disabled/>').val('')
                        .text(list && list.error ? list.error : '{{ lang._("no servers returned") }}'));
                }
            });
        });

        $('#speedlist').change(function () {
            $('#serverid').val($(this).val());
            $('#serverid_error').hide();
        });

        $('#runAct').click(function () {
            let serverid = $('#serverid').val().trim();
            if (serverid !== '' && !/^[1-9][0-9]{0,8}$/.test(serverid)) {
                $('#serverid_error').show();
                return;
            }
            $('#serverid_error').hide();
            busy('runAct', true);
            $('#runAct').prop('disabled', true);
            ajaxCall('/api/speedtestsurfhost/service/run', {'serverid': serverid}, function (r) {
                busy('runAct', false);
                $('#runAct').prop('disabled', false);
                showResult(r);
                statReload();
                logReload();
            });
        });

        $('#deletelogAct').click(function () {
            BootstrapDialog.confirm({
                title: '{{ lang._("Clear history") }}',
                message: '{{ lang._("Delete all stored speedtest results?") }}',
                type: BootstrapDialog.TYPE_DANGER,
                btnOKLabel: '{{ lang._("Delete") }}',
                callback: function (yes) {
                    if (!yes) {
                        return;
                    }
                    ajaxCall('/api/speedtestsurfhost/service/deletelog', {}, function () {
                        statReload();
                        logReload();
                    });
                }
            });
        });

        $('#importAct').click(function () {
            busy('importAct', true);
            ajaxCall('/api/speedtestsurfhost/service/import', {}, function (r) {
                busy('importAct', false);
                $('#import_msg').text(r && r.error ? r.error
                    : (r.message ? r.message : r.imported + ' {{ lang._("results imported") }}'));
                statReload();
                logReload();
            });
        });
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#test">{{ lang._('Speedtest') }}</a></li>
    <li><a data-toggle="tab" href="#settings">{{ lang._('Settings') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="test" class="tab-pane fade in active">
        <table class="table table-condensed">
            <tbody>
                <tr>
                    <td style="width:22%">{{ lang._('Test program') }}</td>
                    <td>
                        <span id="checking">{{ lang._('Checking...') }}</span>
                        <b id="program_name"></b> <span id="program_state"></span>
                        <button class="btn btn-xs btn-primary" id="installAct" type="button" style="display:none">
                            <b>{{ lang._('Install') }}</b> <i id="installAct_progress"></i></button>
                        <button class="btn btn-xs btn-default" id="removeAct" type="button" style="display:none">
                            {{ lang._('Remove') }} <i id="removeAct_progress"></i></button>
                        <div><small id="install_msg"></small></div>
                    </td>
                </tr>
                <tr class="canruntests" style="display:none">
                    <td>{{ lang._('Server') }}</td>
                    <td>
                        <div class="row">
                            <div class="col-md-6">
                                <select id="speedlist" class="form-control">
                                    <option value="">{{ lang._('default server from the settings') }}</option>
                                </select>
                            </div>
                            <div class="col-md-3">
                                <input type="text" id="serverid" class="form-control" inputmode="numeric"
                                       placeholder="{{ lang._('server id (optional)') }}">
                            </div>
                            <div class="col-md-3">
                                <button class="btn btn-default" id="serverlistAct" type="button">
                                    {{ lang._('Get server list') }} <i id="serverlistAct_progress"></i></button>
                            </div>
                        </div>
                        <small id="serverid_error" class="text-danger" style="display:none">
                            {{ lang._('Enter a numeric server id or leave the field empty.') }}</small>
                    </td>
                </tr>
                <tr class="canruntests" style="display:none">
                    <td></td>
                    <td>
                        <button class="btn btn-primary" id="runAct" type="button">
                            <b>{{ lang._('Run speedtest') }}</b> <i id="runAct_progress"></i></button>
                        <small class="text-muted">{{ lang._('A test takes 20 to 60 seconds.') }}</small>
                    </td>
                </tr>
            </tbody>
            <tbody id="test_results" style="display:none">
                <tr><td colspan="2"><div id="res_error" class="text-danger"></div></td></tr>
            </tbody>
            <tbody id="res_rows" style="display:none">
                <tr><td>{{ lang._('Download') }}</td><td><b id="dlspeed"></b></td></tr>
                <tr><td>{{ lang._('Upload') }}</td><td><b id="ulspeed"></b></td></tr>
                <tr><td>{{ lang._('Latency') }}</td><td id="latency"></td></tr>
                <tr><td>{{ lang._('Server') }}</td><td id="server"></td></tr>
                <tr><td>{{ lang._('Public IP') }}</td><td id="client"></td></tr>
                <tr><td>{{ lang._('Result') }}</td><td id="result"></td></tr>
            </tbody>
        </table>

        <table class="table table-condensed">
            <thead>
                <tr><th colspan="2"><h3 style="margin:0">{{ lang._('Statistics') }}</h3></th></tr>
            </thead>
            <tbody>
                <tr><td style="width:22%">{{ lang._('Tests') }}</td><td id="stat_samples">0</td></tr>
                <tr><td>{{ lang._('Download') }}</td><td id="stat_download"></td></tr>
                <tr><td>{{ lang._('Upload') }}</td><td id="stat_upload"></td></tr>
                <tr><td>{{ lang._('Latency') }}</td><td id="stat_latency"></td></tr>
            </tbody>
        </table>

        <table class="table table-condensed table-striped">
            <thead>
                <tr>
                    <th colspan="7">
                        <h3 style="margin:0; display:inline">{{ lang._('History') }}</h3>
                        <small class="text-muted">{{ lang._('latest 50, local time') }}</small>
                        <span class="pull-right">
                            <a class="btn btn-xs btn-default" href="/api/speedtestsurfhost/download/csv">
                                <i class="fa fa-download"></i> {{ lang._('Export CSV') }}</a>
                            <button class="btn btn-xs btn-default" id="importAct" type="button"
                                    title="{{ lang._('Merge the history of os-speedtest-community') }}">
                                {{ lang._('Import community history') }} <i id="importAct_progress"></i></button>
                            <button class="btn btn-xs btn-danger" id="deletelogAct" type="button">
                                {{ lang._('Clear history') }}</button>
                        </span>
                        <div><small id="import_msg"></small></div>
                    </th>
                </tr>
                <tr>
                    <th>{{ lang._('Time') }}</th>
                    <th>{{ lang._('Server id') }}</th>
                    <th>{{ lang._('Server') }}</th>
                    <th>{{ lang._('Download (Mbps)') }}</th>
                    <th>{{ lang._('Upload (Mbps)') }}</th>
                    <th>{{ lang._('Latency (ms)') }}</th>
                    <th>{{ lang._('Result') }}</th>
                </tr>
            </thead>
            <tbody id="log_block"></tbody>
        </table>
    </div>

    <div id="settings" class="tab-pane fade in">
        {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings']) }}
        <div class="col-md-12" style="padding-bottom:1em">
            <button class="btn btn-primary" id="saveAct" type="button">
                <b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
        </div>
    </div>
</div>
