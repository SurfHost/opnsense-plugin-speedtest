# Copyright (c) 2021 Miha Kralj
# Copyright (c) 2026 SurfHost.nl
# SPDX-License-Identifier: BSD-2-Clause

PLUGIN_NAME=		speedtest-surfhost
PLUGIN_VERSION=		1.1
PLUGIN_COMMENT=		Internet speed test with history, schedule and dashboard widget
PLUGIN_LICENSE=		BSD2CLAUSE
PLUGIN_MAINTAINER=	hans@surfhost.nl
PLUGIN_WWW=		https://github.com/SurfHost/opnsense-plugin-speedtest

# No PLUGIN_CONFLICTS on os-speedtest-community: plugins.mk only uses that
# list for 'make upgrade' and never writes it into the package manifest, so
# pkg would not enforce it anyway. Both plugins use their own namespace and
# files, so installing both is harmless.

# When this directory is dropped into an opnsense/plugins checkout under
# net-mgmt/, the standard include below applies unchanged.
.include "../../Mk/plugins.mk"
