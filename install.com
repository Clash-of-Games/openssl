$! INSTALL.COM -- Installs the files in a given directory tree
$!
$! Author: Richard Levitte <richard@levitte.org>
$! Time of creation: 22-MAY-1998 10:13
$!
$! P1	root of the directory tree
$!
$!
$ CURR_DIR = F$ENVIRONMENT("DEFAULT")
$!
$	IF P1 .EQS. ""
$	THEN
$	    WRITE SYS$OUTPUT "First argument missing."
$	    WRITE SYS$OUTPUT "Should be the directory where you want things installed."
$	    EXIT
$	ENDIF
$
$	ARCH = "AXP"
$	IF F$GETSYI("CPU") .LT. 128 THEN ARCH = "VAX"
$
$	ROOT = F$PARSE(P1,"[]A.;0",,,"SYNTAX_ONLY,NO_CONCEAL") - "A.;0"
$	ROOT_DEV = F$PARSE(ROOT,,,"DEVICE","SYNTAX_ONLY")
$	ROOT_DIR = F$PARSE(ROOT,,,"DIRECTORY","SYNTAX_ONLY") -
		   - ".][000000" - "[000000." - "][" - "[" - "]"
$	ROOT = ROOT_DEV + "[" + ROOT_DIR
$!
$ KIT_DIR = "''ROOT'" + "]"
$ KIT_AREA = "''ROOT'" + "...]"
$
$	DEFINE/NOLOG WRK_SSLROOT 'ROOT'.] /TRANS=CONC
$	DEFINE/NOLOG WRK_SSLVLIB WRK_SSLROOT:[VAX_LIB]
$	DEFINE/NOLOG WRK_SSLALIB WRK_SSLROOT:[ALPHA_LIB]
$	DEFINE/NOLOG WRK_SSLLIB WRK_SSLROOT:[LIB]
$	DEFINE/NOLOG WRK_SSLINCLUDE WRK_SSLROOT:[INCLUDE]
$	DEFINE/NOLOG WRK_SSLVEXE WRK_SSLROOT:[VAX_EXE]
$	DEFINE/NOLOG WRK_SSLAEXE WRK_SSLROOT:[ALPHA_EXE]
$	DEFINE/NOLOG WRK_SSLCERTS WRK_SSLROOT:[CERTS]
$	DEFINE/NOLOG WRK_SSLCOM WRK_SSLROOT:[COM]
$	DEFINE/NOLOG WRK_SSLPRIVATE WRK_SSLROOT:[PRIVATE]
$
$	IF F$PARSE("WRK_SSLROOT:[000000]") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLROOT:[000000]
$	IF F$PARSE("WRK_SSLVEXE:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLVEXE:
$	IF F$PARSE("WRK_SSLAEXE:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLAEXE:
$	IF F$PARSE("WRK_SSLVLIB:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLVLIB:
$	IF F$PARSE("WRK_SSLALIB:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLALIB:
$	IF F$PARSE("WRK_SSLLIB:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLLIB:
$	IF F$PARSE("WRK_SSLINCLUDE:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLINCLUDE:
$	IF F$PARSE("WRK_SSLCERTS:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLCERTS:
$	IF F$PARSE("WRK_SSLCOM:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLCOM:
$	IF F$PARSE("WRK_SSLPRIVATE:") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLPRIVATE:
$	IF F$PARSE("WRK_SSLROOT:[VMS]") .EQS. "" THEN -
	   CREATE/DIR/LOG WRK_SSLROOT:[VMS]
$
$	SDIRS := CRYPTO,DEMOS,SSL,APPS,VMS,TEST!,TOOLS
$	EXHEADER := e_os2.h
$
$	COPY 'EXHEADER' WRK_SSLINCLUDE: /LOG
$	SET FILE/PROT=WORLD:RE WRK_SSLINCLUDE:'EXHEADER'
$
$	COPY SSL$PCSI.COM WRK_SSLCOM: /LOG
$	SET FILE/PROT=WORLD:RE WRK_SSLCOM:SSL$PCSI.COM
$!
$! Copy SET_ACLS.COM so that access to the kit area has
$! the appropriate protections as well.
$!
$	COPY SET_ACLS.COM WRK_SSLROOT:[000000]*.* /LOG
$	SET FILE/PROT=WORLD:RE WRK_SSLROOT:[000000]SET_ACLS.COM
$!
$	I = 0
$ LOOP_SDIRS: 
$	D = F$ELEMENT(I, ",", SDIRS)
$	I = I + 1
$	IF D .EQS. "," THEN GOTO LOOP_SDIRS_END
$	WRITE SYS$OUTPUT "Installing ",D," files."
$	SET DEFAULT [.'D']
$	@INSTALL 'ROOT']
$	SET DEFAULT [-]
$	GOTO LOOP_SDIRS
$ LOOP_SDIRS_END:
$!
$ OPEN/WRITE KIT_FILE CREATE_PCSI_KIT.COM
$!
$ WRITE KIT_FILE "$!"
$ WRITE KIT_FILE "$! CREATE_PCSI_KIT.COM -  This command procedure creates the actual .PCSI kit."
$ WRITE KIT_FILE "$!"
$ WRITE KIT_FILE "$!"
$ WRITE KIT_FILE "$!   Do not edit this file."
$ WRITE KIT_FILE "$!   This file is created by INSTALL.COM, and any changes to this file should"
$ WRITE KIT_FILE "$!   be made in INSTALL.COM."
$ WRITE KIT_FILE "$!"
$ WRITE KIT_FILE "$!"
$ WRITE KIT_FILE " $ product package ssl   /destination = ''KIT_DIR' - "
$ WRITE KIT_FILE "                         /format = sequential - "
$ WRITE KIT_FILE "                         /log - "
$ WRITE KIT_FILE "                         /material = ''KIT_AREA' - "
$ WRITE KIT_FILE "                         /source = ''CURR_DIR'CPQ-AXPVMS-SSL-T0100--1.PCSI$DESC "
$ WRITE KIT_FILE "$!"
$ WRITE KIT_FILE "$ kit_file = f$search(""''KIT_DIR'*.PCSI"") "
$ WRITE KIT_FILE "$ spool compress/method=dcx_axpexe  ''KIT_DIR'''KIT_FILE' ''KIT_DIR'"
$!
$ CLOSE KIT_FILE
$!
$	DEASSIGN WRK_SSLROOT
$	DEASSIGN WRK_SSLVLIB
$	DEASSIGN WRK_SSLALIB
$	DEASSIGN WRK_SSLLIB
$	DEASSIGN WRK_SSLINCLUDE
$	DEASSIGN WRK_SSLVEXE
$	DEASSIGN WRK_SSLAEXE
$	DEASSIGN WRK_SSLCERTS
$	DEASSIGN WRK_SSLCOM
$	DEASSIGN WRK_SSLPRIVATE
$!
$	WRITE SYS$OUTPUT ""
$	WRITE SYS$OUTPUT " Now, to include the 32-bit images and libraries, copy the following"
$	WRITE SYS$OUTPUT " from a 32-bit build tree:"
$	WRITE SYS$OUTPUT ""
$	WRITE SYS$OUTPUT " COPY [.AXP.EXE.CRYPTO]LIBCRYPTO32.OLB ''root'.ALPHA_LIB]"
$	WRITE SYS$OUTPUT " COPY [.AXP.EXE.SSL]LIBSSL32.OLB ''root'.ALPHA_LIB]"
$	WRITE SYS$OUTPUT ""
$	WRITE SYS$OUTPUT " COPY [.AXP.EXE.CRYPTO]SSL$LIBCRYPTO_SHR32.EXE ''root'.ALPHA_EXE]"
$	WRITE SYS$OUTPUT " COPY [.AXP.EXE.SSL]SSL$LIBSSL_SHR32.EXE ''root'.ALPHA_EXE]"
$	WRITE SYS$OUTPUT ""
$!	
$	WRITE SYS$OUTPUT ""
$	WRITE SYS$OUTPUT "	Installation done!"
$	WRITE SYS$OUTPUT ""
$	WRITE SYS$OUTPUT "	You might want to purge ",ROOT,"...]"
$	WRITE SYS$OUTPUT ""
$
$	EXIT
