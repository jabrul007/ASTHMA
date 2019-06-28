dm log 'clear' log;
********************************************************************************************

               Study Number: AB07015
    Sponsor Protocol Number: AB07015

               Program Name: adaqlq.sas
           Program Location: I:\STUDIES\AB07015\Dev\Final\programs\datasets\sdtm
                Description: Asthma Symptom

             Program Author: MB
              Creation Date: 14Jan2019

              Datasets Used: libraw: aqlq
                             libext:
                             libshell: 
                             libsdtm: 
                             libadam:

    Name/Location of Output: adaqlq.sas7bdat/I:\STUDIES\AB07015\Dev\Final\datasets\adam
                             

    Derived Dataset Library: libsdtm
Source(raw) Dataset Library: libraw
             Format Library: libraw
   External Macros Location: I:\STUDIES\AB07015\Dev\Final\programs\utils

      Modification Notes (include name of person modifying the program, date of modification
                          And description/reason for the change):

          Modification Code:                                                              
       Date of Modification:                                                              
           Name of Modifier:                                                              
         Description/Reason:     


************************************************************************;
/***********************************************************************/
/*************                Setup Section               **************/
/***********************************************************************/


%global type program;
%let type = Datasets; 
%let program = adaqlq22222; 

%let this=Jabrul;

/***********************************************************************/
/*************                Programming Section         **************/
/***********************************************************************/

data ds(keep=subjid dsdecod dsdt dsflg);
  set libsdtm.ds;
	where UPCASE(DSDECOD) in ("LACK OF EFFICACY", "NON FATAL ADVERSE EVENT", "OTHER");

  subjid=substr(usubjid,9);
	dsdt=input(DSSTDTC,yymmdd10.);
	dsflg=1;

	format dsdt ddmmyy10.;
run;

proc sort nodupkey;
  by subjid;
run;


data aqlq;
    set libraw.aqlq;
    keep SUBJID VIS AQQDTC AQQDT Q1-Q31;
run;

proc sort data = aqlq out=s_aqlq;
    where not missing(AQQDTC);
    by subjid VIS AQQDTC AQQDT;
run;

proc sql noprint;
  select distinct quote(subjid)
	into: pt separated by ","
	from s_aqlq;
quit;


data visit(keep=subjid vis VISDT);
  set libraw.visit2;
	where subjid in (&pt.) and 0 le vis le 36;
run;



data aqlq2;
  merge s_aqlq
	      visit
				;
	by subjid vis;
run;


%MACRO AQLQIMP();

		data aqlq3;
		  merge aqlq2(in=a)
			      ds;
			by subjid;
			if a;
		run;

		data aqlq4;
		  set aqlq3;
			by subjid;

			if dsflg=1 then do;

				%do i=1 %to 31;

			  	retain q_&i.;

					if first.subjid then q_&i.=. ;
					else if q&i. ne . then q_&i.=. ;
				    
	      %end;

				output;

				%do i=1 %to 31;
				  if q&i. ne . then q_&i.=q&i.;
				%end;
			end;
			else do;
        output;
			end;

		run;

		data aqimpute(drop=q_:);
		  set aqlq4;
			%do i=1 %to 31;
				if dsflg=1 and q&i. eq . and q_&i. ne . then do;
					q&i.=q_&i.;
				end;
			%end;
		run;


%MEND AQLQIMP;

%AQLQIMP;


proc transpose data = aqimpute out=t_aqlq;
    by subjid vis AQQDTC AQQDT;
    var Q:;
run;


/*proc transpose data = s_aqlq out=t_aqlq;*/
/*    by subjid vis AQQDTC AQQDT;*/
/*    var Q:;*/
/*run;*/

data aqlq1;
    set t_aqlq;
    if _name_ in ('Q1' 'Q2' 'Q3' 'Q4' 'Q5') then fmtname='AQLQPI';
    if _name_ in ('Q6' 'Q12') then fmtname='AQLQPII';
    if _name_ in ('Q7' 'Q8' 'Q9' 'Q10' 'Q11' 'Q13' 'Q14' 'Q15' 'Q16' 'Q17' 'Q18' 'Q19' 'Q20' 
                  'Q21' 'Q22' 'Q23' 'Q24' 'Q25' 'Q26' 'Q27' 'Q28' 'Q29' 'Q30') then fmtname='AQLQPIIB';
    if _name_ in ('Q31') then fmtname='AQLQPV';

proc sort data=aqlq1; by col1 fmtname ;
run;

PROC FORMAT LIB = WORK.FORMATS CNTLOUT = WORK.formats (keep=FMTNAME START END LABEL type);
run;

data format;
    set formats;
    where fmtname in ('AQLQPI' 'AQLQPII' 'AQLQPIIB' 'AQLQPV');

    COL1=input(strip(START),8.);
run;

proc sort data = format;
    by  COL1 fmtname;
run;

data fin;
    length fmtname $50.;
    merge aqlq1(in=a) format(in=b);
    by  COL1 fmtname;
    if a ;

    rename _name_=paramcd _label_=param col1=aval label=avalc;

    label _name_='Paramcd'
          _label_='PARAM'
          label='AVALC'
          col1='AVAL';

run;

proc sort data=fin;
    by subjid VIS AQQDTC AQQDT;
run;

data adsl;
    set libadam.adsl;
    where trt01p ne 'Screen Failure';
    keep studyid usubjid subjid trt01p;
run;

data _final;
    length subjid $50.;
    merge fin(in=a) adsl(in=b);
    by subjid;

    if a and b;

    id=input(substr(PARAMCD,2),best12.);
    rename trt01p=trtp;
run;

proc sort data = _final out=_final2(keep=studyid usubjid subjid VIS id paramcd param trtp aval avalc 
                                    rename=(aval=locf avalc=locfc));
  by studyid usubjid subjid VIS id paramcd param trtp AQQDTC AQQDT ;
run;


data aqlq_main;
  set libadam.adaqlq;

  id=input(substr(PARAMCD,2),best12.);
run;

proc sort;
  by studyid usubjid subjid VIS id paramcd param trtp;
run;

data final(drop=id);
  merge aqlq_main
	      _final2;
  by studyid usubjid subjid VIS id paramcd param trtp;
run;

 
proc sql;
  create table libadam.adaqlq_locf(label="Asthma Quality of Life Questionnaire") as select 
  STUDYID   label='Study Identifier' length=15,
  USUBJID   label='Unique Subject Identifier' length=25,
  SUBJID    label='Subject Identifier for the Study' length=25,
  TRTP      label='Planned Treatment' length=100,
  PARAM     label='PARAM' length=25,
  PARAMCD   label='PARAMCD' length=25,
  Vis     	label='Visit' length=8,
  AQQDTC   	label='Visit Date' length=20,
  AQQDT   	label='Visit Date[n]' length=8,
  AVAL     	label='AVAL' length=8,
  AVALC     label='AVALC' length=50,
  LOCF     	label='AVAL (LOCF)' length=8,
  LOCFC     label='AVALC (LOCF)' length=50

  from final ;
quit;

/***********************************************************************/
/*************                Creating log and lst        **************/
/***********************************************************************/

/*DM LOG 'LOG; FILE "&path\programs\&type\sdtm\logs\&program..log" REPLACE' log;*/
/*DM OUTPUT 'OUTPUT; FILE "&path\programs\&type\sdtm\output\&program..lst" REPLACE' output;*/

*** End of the Program ***;
