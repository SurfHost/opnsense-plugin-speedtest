<?php

/*
 * Copyright (c) 2026 SurfHost.nl
 * SPDX-License-Identifier: BSD-2-Clause
 */

namespace OPNsense\SpeedtestSurfHost;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/SpeedtestSurfHost/index');
        $this->view->generalForm = $this->getForm('general');
    }
}
