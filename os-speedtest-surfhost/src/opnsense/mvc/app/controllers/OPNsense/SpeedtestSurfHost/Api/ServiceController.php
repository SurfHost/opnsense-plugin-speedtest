<?php

/*
 * Copyright (c) 2021 Miha Kralj
 * Copyright (c) 2026 SurfHost.nl
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

namespace OPNsense\SpeedtestSurfHost\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiControllerBase
{
    /**
     * configd answers with the script's JSON; anything else (an execute
     * error, a timeout) is wrapped so the page always gets an object.
     * @return array
     */
    private function configd($action, $params = [])
    {
        $backend = new Backend();
        $raw = $params === []
            ? $backend->configdRun($action)
            : $backend->configdpRun($action, $params);
        $data = json_decode(trim((string)$raw), true);
        if (!is_array($data)) {
            $raw = trim((string)$raw);
            return ['error' => $raw !== '' ? $raw : gettext('No answer from configd')];
        }
        return $data;
    }

    public function versionAction()
    {
        return $this->configd('speedtestsurfhost version');
    }

    public function serverlistAction()
    {
        return $this->configd('speedtestsurfhost serverlist');
    }

    public function statAction()
    {
        return $this->configd('speedtestsurfhost stat');
    }

    public function logAction()
    {
        return $this->configd('speedtestsurfhost log');
    }

    public function recentAction()
    {
        return $this->configd('speedtestsurfhost recent');
    }

    /**
     * Run a test now. An empty id uses the server from the settings (or
     * lets the backend pick the nearest one when that is empty too).
     * @return array
     */
    public function runAction()
    {
        if (!$this->request->isPost()) {
            return ['error' => gettext('POST required')];
        }
        $serverid = trim((string)$this->request->getPost('serverid'));
        if ($serverid === '') {
            $serverid = 'default';
        } elseif (!preg_match('/^[1-9][0-9]{0,8}$/D', $serverid)) {
            return ['error' => sprintf(gettext('%s is not a valid server id'), $serverid)];
        }
        return $this->configd('speedtestsurfhost run', [$serverid]);
    }

    public function deletelogAction()
    {
        if (!$this->request->isPost()) {
            return ['error' => gettext('POST required')];
        }
        return $this->configd('speedtestsurfhost deletelog');
    }

    /**
     * After Save: render the settings for the scripts, regenerate the
     * crontab, and install the chosen test program (removing the other one).
     * The Ookla binary is only fetched when its terms were accepted; the
     * install script checks that again in the rendered settings.
     * @return array
     */
    public function reconfigureAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error', 'message' => gettext('POST required')];
        }
        $backend = new Backend();
        $backend->configdRun('template reload OPNsense/SpeedtestSurfHost');
        $backend->configdRun('cron restart');
        return $this->configd('speedtestsurfhost sync');
    }
}
