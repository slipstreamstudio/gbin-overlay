# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/media-tv/xbmc/xbmc-pvr-9999.ebuild,v 1.00 2011/06/02 00:44:00 alexb38 Exp $

EAPI="2"

inherit eutils python

EGIT_REPO_URI="git://github.com/opdenkamp/xbmc.git"
if [[ ${PV} == "9999" ]] ; then
        inherit git autotools
        EGIT_BRANCH="Eden-pvr"
else
        inherit autotools
        MY_P=${P/_/-}
        SRC_URI="mirror://sourceforge/${PN}/${MY_P}.tar.gz"
        KEYWORDS="~amd64 ~x86"
        S=${WORKDIR}/${MY_P}
fi

DESCRIPTION="XBMC is a free and open source media-player and entertainment hub"
HOMEPAGE="http://xbmc.org/"

LICENSE="GPL-2"
SLOT="0"
IUSE="alsa altivec avahi bluray css debug joystick midi profile pulseaudio rtmp sse sse2 udev vaapi vdpau webserver +xrandr"

COMMON_DEPEND="virtual/opengl
        app-arch/bzip2
        app-arch/unzip
        app-arch/zip
        app-i18n/enca
        >=dev-lang/python-2.4
        dev-libs/boost
        dev-libs/fribidi
        dev-libs/libcdio[-minimal]
        dev-libs/libpcre[cxx]
        >=dev-libs/lzo-2.04
        >=dev-python/pysqlite-2
        media-libs/alsa-lib
        media-libs/flac
        media-libs/fontconfig
        media-libs/freetype
        >=media-libs/glew-1.5.6
        media-libs/jasper
        media-libs/jbigkit
        virtual/jpeg
        >=media-libs/libass-0.9.7
        bluray? ( media-libs/libbluray )
        css? ( media-libs/libdvdcss )
        media-libs/libmad
        media-libs/libmodplug
        media-libs/libmpeg2
        media-libs/libogg
        media-libs/libsamplerate
        media-libs/libsdl[audio,opengl,video,X]
        alsa? ( media-libs/libsdl[alsa] )
        media-libs/libvorbis
        media-libs/sdl-gfx
        >=media-libs/sdl-image-1.2.10[gif,jpeg,png]
        media-libs/sdl-mixer
        media-libs/sdl-sound
        media-libs/tiff
        dev-libs/yajl
        pulseaudio? ( media-sound/pulseaudio )
        media-sound/wavpack
        rtmp? ( media-video/rtmpdump )
        avahi? ( net-dns/avahi )
        webserver? ( net-libs/libmicrohttpd )
        net-misc/curl
        || ( >=net-fs/samba-3.4.6[smbclient] <net-fs/samba-3.3 )
        sys-apps/dbus
        sys-libs/zlib
        virtual/mysql
        x11-apps/xdpyinfo
        x11-apps/mesa-progs
        vaapi? ( x11-libs/libva )
        vdpau? (
                || ( x11-libs/libvdpau >=x11-drivers/nvidia-drivers-180.51 )
        )
        x11-libs/libXinerama
        xrandr? ( x11-libs/libXrandr )
        x11-libs/libXrender
        !media-tv/xbmc
        net-wireless/bluez"
#        <net-wireless/bluez-4.98
# The cpluff bundled addon uses gettext which needs CVS ...
RDEPEND="${COMMON_DEPEND}
        udev? ( sys-fs/udisks sys-power/upower )"
DEPEND="${COMMON_DEPEND}
        dev-util/gperf
        dev-vcs/cvs
        x11-proto/xineramaproto
        dev-util/cmake
        x86? ( dev-lang/nasm )"

src_unpack() {
        if [[ ${PV} == "9999" ]] ; then
                git_src_unpack
                cd "${S}"
                rm -f configure
        else
                unpack ${A}
                cd "${S}"
        fi

        # Fix case sensitivity
        mv media/Fonts/{a,A}rial.ttf || die
        mv media/{S,s}plash.png || die
}

src_prepare() {
        # patches for latests revisions of ffmpeg, some functions changed
        # epatch "${FILESDIR}"/${PN}-9999-ffmpeg-9999.patch
        # stolen from the aoliynik xbmc-9999 ebuild
        epatch "${FILESDIR}"/${P}-libpng-1.5.patch #380127
        epatch "${FILESDIR}"/${P}-libpng-1.5-fix-plt-trn-get.patch
        #epatch "${FILESDIR}"/${P}-headers.patch #380127

        # some dirs ship generated autotools, some dont
        local d
        for d in . lib/{libdvd/lib*/,cpluff,libapetag,libid3tag/libid3tag} xbmc/screensavers/rsxs-* ; do
                [[ -e ${d}/configure ]] && continue
                pushd ${d} >/dev/null
                einfo "Generating autotools in ${d}"
                eautoreconf
                popd >/dev/null
        done

        local squish #290564
        use altivec && squish="-DSQUISH_USE_ALTIVEC=1 -maltivec"
        use sse && squish="-DSQUISH_USE_SSE=1 -msse"
        use sse2 && squish="-DSQUISH_USE_SSE=2 -msse2"
        sed -i \
                -e '/^CXXFLAGS/{s:-D[^=]*=.::;s:-m[[:alnum:]]*::}' \
                -e "1iCXXFLAGS += ${squish}" \
                lib/libsquish/Makefile.in || die

        # Fix XBMC's final version string showing as "exported"
        # instead of the SVN revision number.
        export HAVE_GIT=no GIT_REV=${EGIT_VERSION:-exported}

        # Avoid lsb-release dependency
        sed -i \
                -e 's:lsb_release -d:cat /etc/gentoo-release:' \
                xbmc/utils/SystemInfo.cpp || die

        # avoid long delays when powerkit isn't running #348580
        sed -i \
                -e '/dbus_connection_send_with_reply_and_block/s:-1:3000:' \
                xbmc/linux/*.cpp || die

        epatch_user #293109

        # Tweak autotool timestamps to avoid regeneration
        find . -type f -print0 | xargs -0 touch -r configure
}

src_configure() {
        # Disable documentation generation
        export ac_cv_path_LATEX=no
        # Avoid help2man
        export HELP2MAN=$(type -P help2man || echo true)

        econf \
                --docdir=/usr/share/doc/${PF} \
                --disable-ccache \
                --disable-optimizations \
                --enable-gl \
                $(use_enable avahi) \
                $(use_enable bluray libbluray) \
                $(use_enable css dvdcss) \
                $(use_enable debug) \
                --disable-hal \
                $(use_enable joystick) \
                $(use_enable midi mid) \
                $(use_enable profile profiling) \
                $(use_enable pulseaudio pulse) \
                $(use_enable rtmp) \
                $(use_enable vaapi) \
                $(use_enable vdpau) \
                $(use_enable webserver) \
                $(use_enable xrandr)
}

src_install() {
        emake install DESTDIR="${D}" || die
        prepalldocs

        insinto /usr/share/applications
        doins tools/Linux/xbmc.desktop
        doicon tools/Linux/xbmc.png

        insinto "$(python_get_sitedir)" #309885
        doins tools/EventClients/lib/python/xbmcclient.py || die
        newbin "tools/EventClients/Clients/XBMC Send/xbmc-send.py" xbmc-send || die
}

pkg_postinst() {
        elog "Visit http://wiki.xbmc.org/?title=XBMC_Online_Manual"
}
