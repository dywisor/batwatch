EAPI=5

EGIT_REPO_URI="git://github.com/dywisor/${PN}.git"

inherit user bash-completion-r1 git-r3

DESCRIPTION="run scripts when battery is low"
HOMEPAGE="https://github.com/dywisor/batwatch"
SRC_URI=""

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS=""
IUSE=""

_CDEPEND="
	sys-libs/glibc:=
	>=dev-libs/glib-2.32:2=
	>=sys-power/upower-0.9.20:=
"
DEPEND="${_CDEPEND}
	virtual/pkgconfig"
RDEPEND="${_CDEPEND}"

pkg_preinst() {
	enewgroup ${PN}
	enewuser ${PN} -1 -1 -1 ${PN}
}

src_configure() {
	:
}

src_install() {
	emake -j1 DESTDIR="${D}" BASHCOMPDIR="${D%/}/$(get_bashcompdir)" \
		install-{all,openrc}
	dodoc README.rst
}

pkg_postinst() {
	elog "/etc/sudoers.d/${PN} has been installed,"
	elog "which allows the ${PN} group to execute system power commands."
	elog "You may want to disable this by replacing the file:"
	elog "ln -fs /dev/null /etc/sudoers.d/${PN}"
}
