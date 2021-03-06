{ stdenv, fetchFromGitHub, fetchpatch
, libxslt, docbook_xsl, docbook_xml_dtd_44
, sysfsutils, openssl, libcap, libgcrypt, nettle, libidn2
}:

let
  time = "20180629";
in
stdenv.mkDerivation rec {
  name = "iputils-${time}";

  src = fetchFromGitHub {
    owner = "iputils";
    repo = "iputils";
    rev = "s${time}";
    sha256 = "19rpl48pjgmyqlm4h7sml5gy7yg4cxciadxcs24q1zj40c05jls0";
  };

  patches = [
   (fetchpatch {
      name = "dont-hardcode-the-location-of-xsltproc.patch";
      url = "https://github.com/iputils/iputils/commit/d0ff83e87ea9064d9215a18e93076b85f0f9e828.patch";
      sha256 = "05wrwf0bfmax69bsgzh3b40n7rvyzw097j8z5ix0xsg0kciygjvx";
    })
  ];

  prePatch = ''
    substituteInPlace doc/custom-man.xsl \
      --replace "http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl" "${docbook_xsl}/xml/xsl/docbook/manpages/docbook.xsl"
    for xmlFile in doc/*.xml; do
      substituteInPlace $xmlFile \
        --replace "http://www.oasis-open.org/docbook/xml/4.4/docbookx.dtd" "${docbook_xml_dtd_44}/xml/dtd/docbook/docbookx.dtd"
    done
  '';

  # Disable idn usage w/musl: https://github.com/iputils/iputils/pull/111
  makeFlags = [ "USE_GNUTLS=no" ] ++ stdenv.lib.optional stdenv.hostPlatform.isMusl "USE_IDN=no";

  nativeBuildInputs = [ libxslt.bin ];
  buildInputs = [
    sysfsutils openssl libcap libgcrypt nettle
  ] ++ stdenv.lib.optional (!stdenv.hostPlatform.isMusl) libidn2;

  # ninfod probably could build on cross, but the Makefile doesn't pass --host etc to the sub configure...
  buildFlags = "man all" + stdenv.lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform) " ninfod";

  installPhase =
    ''
      mkdir -p $out/bin
      cp -p arping clockdiff ping rarpd rdisc tftpd tracepath traceroute6 $out/bin/
      if [ -x ninfod/ninfod ]; then
        cp -p ninfod/ninfod $out/bin
      fi

      mkdir -p $out/share/man/man8
      cd doc
      cp -p \
        arping.8 clockdiff.8 ninfod.8 pg3.8 ping.8 rarpd.8 rdisc.8 tftpd.8 tracepath.8 traceroute6.8 \
        $out/share/man/man8
    '';

  meta = with stdenv.lib; {
    homepage = https://github.com/iputils/iputils;
    description = "A set of small useful utilities for Linux networking";
    license = with licenses; [ gpl2Plus bsd3 ]; # TODO: AS-IS, SUN MICROSYSTEMS license
    platforms = platforms.linux;
    maintainers = with maintainers; [ primeos lheckemann ];
  };
}
