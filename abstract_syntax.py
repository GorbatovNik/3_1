Grammar -> "$AXIOM" NTERM NLs ["$NTERM" {NTERM} NLs] "$TERM" TERM {Term} NLs Rule {Rule}.
Rule -> "$RULE" NTERM ASSIGN RightSideAlt {NLs RightSideAlt} {NL}.
RightSideAlt -> "$EPS" | ((NTERM | TERM) {NTERM | TERM}).
NLs -> NL {NL} | NL.
-----------------------------------------------------------------------------------
Grammar -> "$AXION" NTERM NLs NTermDeclOpt "$TERM" TERM TermList NLs Rule RuleList.
NTermDeclOpt -> "$NTERM" NTermList NLs.
NTermList -> NTERM NTermList | .
TermList -> TERM TermList | .
RuleList -> Rule RuleList | .
Rule -> "$RULE" NTERM ASSIGN RightSideAlt NLs RightSideAltListOpt NLsOpt.
RightSideAlt -> "$EPS" | ((NTERM | TERM) NTermOrTermListOpt).
NTermOrTermListOpt -> (NTERM | TERM) NTermOrTermListOpt | .
RightSideAltListOpt -> RightSideAlt NLs RightSideAltListOpt | .
NLs -> NL NLsOpt | NL.
NLsOpt -> NL NLsOpt | .
-----------------------------------------------------------------------------------
$AXIOM Grammar
$NTERM NTermDeclOpt NTermList TermList RuleList Rule RightSideAlt NTermOrTermListOpt RightSideAltListOpt NLs NLsOpt NTermOrTerm
$TERM "$AXION" "$NTERM" "$TERM" "$RULE" "$EPS" "NTERM" "TERM" "NL" "ASSIGN"

$RULE Grammar = "$AXION" "NTERM" NLs NTermDeclOpt "$TERM" "TERM" TermList NLs Rule RuleList
$RULE NTermDeclOpt = "$NTERM" NTermList NLs
$RULE NTermList = "NTERM" NTermList
				  $EPS
$RULE TermList = "TERM" TermList
				  $EPS
$RULE RuleList = Rule RuleList
				  $EPS
$RULE Rule = "$RULE" "NTERM" "ASSIGN" RightSideAlt NLs RightSideAltListOpt NLsOpt
$RULE RightSideAlt = "$EPS"
					 NtermOrTerm NTermOrTermListOpt
$RULE NTermOrTerm = "NTERM"
					"TERM"
$RULE NTermOrTermListOpt = NtermOrTerm NTermOrTermListOpt
						   $EPS
$RULE RightSideAltListOpt = RightSideAlt NLs RightSideAltListOpt
							$EPS
$RULE NLs = "NL" NLsOpt
			"NL"
$RULE NLsOpt = "NL" NLsOpt
			   $EPS
