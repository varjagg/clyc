#|
  Copyright (c) 2019-2026 White Flame

  This file is part of Clyc
 
  Clyc is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
 
  Clyc is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Affero General Public License for more details.
 
  You should have received a copy of the GNU Affero General Public License
  along with Clyc.  If not, see <https://www.gnu.org/licenses/>.
 
This file derives from work covered by the following copyright
and permission notice:

  Copyright (c) 1995-2009 Cycorp Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
  
  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
|#

(in-package :clyc)

;;; Variables

(defparameter *skolem-arg-sort* nil
  "[Cyc] Variable mapping for current skolem defn.")

(deflexical *formula-constant-str-caching-state* nil)

(defparameter *recompute-skolem-defn-info* nil
  "[Cyc] Bound while recomputing skolem defns.")

(deflexical *skolems-with-known-issues*
  (list
    #$ThePrototypicalFixedAritySkolemFunction
    #$SKF-4855075916
    #$SKF-9401565
    #$SKF-30608153
    #$SKF-358427
    #$SKF-981029
    #$SKF-378457
    #$SKF-7897525238
    #$SKF-23426283
    #$SKF-4978723980
    #$SKF-8095780367
    #$SKF-2283707389
    #$SKF-3819196850
    #$SKF-2177078880
    #$SKF-9178370244
    #$SKF-2313708415
    #$SKF-54808499
    #$SKF-2396342019
    #$SKF-0540013113
    #$SKF-7329112212
    #$SKF-2463549462
    #$SKF-7267986583
    #$SKF-2341431804
    #$SKF-5635570701
    #$SKF-8712676684
    #$SKF-6439069748
    #$SKF-3035846539
    #$SKF-9609006789
    #$SKF-2094656502
    #$SKF-1622895730
    #$SKF-6034791567
    #$SKF-8429706273
    #$SKF-5002539315
    #$SKF-7731242586
    #$SKF-1935351914
    #$SKF-5819554541
    #$SKF-7665225690
    #$SKF-5742181768
    #$SKF-7774820049
    #$SKF-9832002172
    #$SKF-9099460346
    #$SKF-6802057837
    #$SKF-0233545031
    #$SKF-7143243607
    #$SKF-5547792583
    #$SKF-1970550724
    #$SKF-2043784885
    #$SKF-1714183462
    #$SKF-6071957396
    #$SKF-7004599156
    #$SKF-0633671947
    #$SKF-4928965872
    #$SKF-4365040835
    #$SKF-9778251013
    #$SKF-8146092452
    #$SKF-0882987459
    #$SKF-6693421741
    #$SKF-1800635573
    #$SKF-5174206356
    #$SKF-8137704160
    #$SKF-6138620537
    #$SKF-6954747722
    #$SKF-8822929547
    #$SKF-6574888924
    #$SKF-4648710733
    #$SKF-3574121958
    #$SKF-7111033530
    #$SKF-1259710929
    #$SKF-9511328868
    #$SKF-7988430072
    #$SKF-9334424285
    #$SKF-0241028856
    #$SKF-8824048486
    #$SKF-4709173148
    #$SKF-9085853324
    #$SKF-5615627058
    #$SKF-6491665291
    #$SKF-0256832978
    #$SKF-1494753028
    #$SKF-3439360561
    #$SKF-4359556905
    #$SKF-1746016905
    #$SKF-4430979996
    #$SKF-5792768502
    #$SKF-5965884944
    #$SKF-4975731367
    #$SKF-2918153882
    #$SKF-0992686716
    #$SKF-8537516687
    #$SKF-7685719048
    #$SKF-1488659619
    #$SKF-9837174340
    #$SKF-0372211184
    #$SKF-6796242698
    #$SKF-4631282123
    #$SKF-8747036173
    #$SKF-9214557550
    #$SKF-2969771224
    #$SKF-3201009743
    #$SKF-8199787846
    #$SKF-1857924337
    #$SKF-2577476768
    #$SKF-9606922473
    #$SKF-3890236588
    #$SKF-2976547342
    #$SKF-2734536924
    #$SKF-4107434815
    #$SKF-8121330546
    #$SKF-0714339318
    #$SKF-3616130689
    #$SKF-4918966
    #$SKF-12370394
    #$SKF-58467056
    #$SKF-61049284
    #$SKF-14302329
    #$SKF-4779393528
    #$SKF-1305979122
    #$SKF-7033956451
    #$SKF-4442841559))

(deflexical *skolems-safe-to-recanonicalize-at-el*
  (list
    #$SKF-16971619
    #$SKF-9662286
    #$SKF-45878693
    #$SKF-27834981
    #$SKF-12369461
    #$SKF-10688698
    #$SKF-45547787
    #$SKF-31789746
    #$SKF-26692934
    #$SKF-48466118
    #$SKF-60531811
    #$SKF-29624762
    #$SKF-22643466
    #$SKF-29472649
    #$SKF-6535610808
    #$SKF-6391880459
    #$SKF-6069753105
    #$SKF-1836062444
    #$SKF-1140288587
    #$SKF-0975510193
    #$SKF-0417114039
    #$SKF-2399775374
    #$SKF-9741300383
    #$SKF-0828551493
    #$SKF-2588418129
    #$SKF-1857929740
    #$SKF-9771221235
    #$SKF-5248881133
    #$SKF-30037247
    #$SKF-60060919
    #$SKF-10786079
    #$SKF-14077376
    #$SKF-55914574
    #$SKF-16648407
    #$SKF-44601733
    #$SKF-7913899905
    #$SKF-4396958760
    #$SKF-8020199718
    #$SKF-20333
    #$SKF-3701677947
    #$SKF-2758282998
    #$SKF-32592026
    #$SKF-15476867
    #$SKF-11623545
    #$SKF-39071040
    #$SKF-22133371
    #$SKF-49114437
    #$SKF-6397777
    #$SKF-27545347
    #$SKF-44682034
    #$SKF-55141454
    #$SKF-29896988
    #$SKF-42443574
    #$SKF-13447977
    #$SKF-30519480
    #$SKF-62227276
    #$SKF-17408839
    #$SKF-58430677
    #$SKF-59662976
    #$SKF-12620975
    #$SKF-9433064
    #$SKF-9205245
    #$SKF-DepictedGroupMember
    #$SKF-19625320
    #$SKF-3784346661
    #$SKF-6544284149
    #$SKF-0614825063
    #$SKF-0016213450
    #$SKF-22649603
    #$SKF-4118636
    #$SKF-19878232
    #$SKF-15013378
    #$SKF-65815517
    #$SKF-56452378
    #$SKF-49139121
    #$SKF-12749049
    #$SKF-2910558946
    #$SKF-2910558946
    #$SKF-8609688279
    #$SKF-3254220233
    #$SKF-4116454483
    #$SKF-9882206036
    #$SKF-7876960574
    #$SKF-7849157406
    #$SKF-0013694801
    #$SKF-3786700124
    #$SKF-1714230847
    #$SKF-7566265665
    #$SKF-8055872557
    #$SKF-6624619390
    #$SKF-4749393956
    #$SKF-9902000475
    #$SKF-2176445673
    #$SKF-9582976901
    #$SKF-62641426
    #$SKF-37581079
    #$SKF-9780389
    #$SKF-51938893
    #$SKF-33012437
    #$SKF-9412760
    #$SKF-22314298
    #$SKF-52903378
    #$SKF-59517423
    #$SKF-24705784
    #$SKF-22566254
    #$SKF-35236481
    #$SKF-26725746
    #$SKF-55356852
    #$SKF-3634339
    #$SKF-65815517
    #$SKF-56452378
    #$SKF-49139121
    #$SKF-12749049
    #$SKF-4408119749
    #$SKF-3789312666
    #$SKF-0283155048
    #$SKF-9294061441
    #$SKF-4876245588
    #$SKF-2809645919
    #$SKF-1124554131
    #$SKF-0220610914
    #$SKF-4790221775
    #$SKF-1168015263
    #$SKF-4318796173
    #$SKF-1828131226
    #$SKF-2199671088
    #$SKF-9895165404
    #$SKF-6604522774
    #$SKF-6086634185
    #$SKF-0428133650
    #$SKF-7899934995
    #$SKF-0860923384
    #$SKF-4146570201
    #$SKF-0406242321
    #$SKF-4468030352
    #$SKF-8519691249
    #$SKF-6471415053
    #$SKF-6816884555
    #$SKF-2207590761
    #$SKF-4785728462
    #$SKF-6959780810
    #$SKF-2698165023
    #$SKF-1592332182
    #$SKF-9127604959
    #$SKF-3352641286
    #$SKF-9726105841
    #$SKF-0624682876
    #$SKF-9673514545
    #$SKF-1902545429
    #$SKF-6876074534
    #$SKF-8288491486
    #$SKF-4637358284
    #$SKF-0635199939
    #$SKF-4292973565
    #$SKF-7798353664
    #$SKF-34523039
    #$SKF-33538847
    #$SKF-58036047
    #$SKF-9708075
    #$SKF-13094314
    #$SKF-27004431
    #$SKF-47290403
    #$SKF-49713991
    #$SKF-40178904
    #$SKF-62659908
    #$SKF-61484227
    #$SKF-35458681
    #$SKF-17599345
    #$SKF-53668837
    #$SKF-24102297
    #$SKF-32709431
    #$SKF-51752162
    #$SKF-35359227
    #$SKF-20847759
    #$SKF-51781280
    #$SKF-51473172
    #$SKF-36777684
    #$SKF-27183984
    #$SKF-24538299
    #$SKF-51270566
    #$SKF-6498804
    #$SKF-52375281
    #$SKF-59156909
    #$SKF-59507392
    #$SKF-21555986
    #$SKF-0925186357
    #$SKF-6223276020
    #$SKF-5400448981
    #$SKF-0033649819
    #$SKF-8779626658
    #$SKF-2650598318
    #$SKF-1317366451
    #$SKF-5713244721
    #$SKF-5494021688
    #$SKF-50021281
    #$SKF-52700384
    #$SKF-27017330
    #$SKF-6926447
    #$SKF-57742011
    #$SKF-32797409
    #$SKF-36775099
    #$SKF-8803460
    #$SKF-11685259
    #$SKF-49596986
    #$SKF-1515868
    #$SKF-12425256
    #$SKF-26526786
    #$SKF-757265
    #$SKF-66361621
    #$SKF-50135687
    #$SKF-28256974
    #$SKF-52059331
    #$SKF-60879947
    #$SKF-10095100
    #$SKF-20576203
    #$SKF-49828332
    #$SKF-44916076
    #$SKF-63714570
    #$SKF-3886762
    #$SKF-14991605
    #$SKF-35022890
    #$SKF-9692584
    #$SKF-56789029
    #$SKF-63331999
    #$SKF-60839916
    #$SKF-11805601
    #$MarriedCoupleFn
    #$SKF-54717125
    #$SKF-47103024
    #$SKF-32504795
    #$SKF-50991035
    #$SKF-54893967
    #$SKF-4588740
    #$SKF-34044423
    #$SKF-23158350
    #$SKF-26216492
    #$SKF-23792367
    #$SKF-26655735
    #$SKF-36384184
    #$SKF-28223401
    #$SKF-30705866
    #$SKF-31089449
    #$SKF-43795517
    #$SKF-54692934
    #$SKF-62874373
    #$SKF-13198899
    #$SKF-6598020
    #$SKF-66712623
    #$SKF-61590093
    #$SKF-4298210
    #$SKF-13358052
    #$SKF-1077450
    #$SKF-27216176
    #$SKF-28083191
    #$SKF-539243
    #$SKF-14104209
    #$SKF-6066610
    #$SKF-14779626
    #$SKF-1007216
    #$SKF-49463821
    #$SKF-764714
    #$SKF-59277817
    #$SKF-24473185
    #$SKF-22799176
    #$SKF-13378825
    #$SKF-8692086
    #$SKF-59150515
    #$SKF-6649426
    #$SKF-18423567
    #$SKF-61014428
    #$SKF-612301
    #$SKF-390407
    #$SKF-469762
    #$SKF-57350382
    #$SKF-550621
    #$SKF-41449368
    #$SKF-20918103
    #$SKF-447007
    #$SKF-1383963
    #$SKF-348190
    #$SKF-693803
    #$SKF-133452
    #$SKF-2813385
    #$SKF-31097107
    #$SKF-57888
    #$SKF-10895131
    #$SKF-13225721
    #$SKF-43450038
    #$SKF-21119958
    #$SKF-47744038
    #$SKF-466900
    #$SKF-46555292
    #$SKF-23253528
    #$SKF-924570
    #$SKF-BandMemPlaying
    #$SKF-48376054
    #$SKF-121716
    #$SKF-7364934
    #$SKF-14760742
    #$SKF-17172575
    #$SKF-23584353
    #$SKF-53200158
    #$SKF-48653451
    #$SKF-55897365
    #$SKF-52891476
    #$SKF-33105457
    #$SKF-10518089
    #$SKF-33158362
    #$SKF-66304485
    #$SKF-810295
    #$SKF-968219
    #$SKF-9855449
    #$SKF-51029398
    #$SKF-9874778
    #$SKF-14008069
    #$SKF-197207
    #$SKF-9176578
    #$SKF-62825
    #$SKF-476059
    #$SKF-366078
    #$SKF-17345463
    #$SKF-51339287
    #$SKF-1046930
    #$SKF-828757
    #$SKF-51633710
    #$SKF-19769806
    #$SKF-46906520
    #$SKF-20309046
    #$SKF-7477821
    #$SKF-21294579
    #$SKF-17746
    #$SKF-42407080
    #$SKF-32539269
    #$SKF-17651656
    #$SKF-49636199
    #$SKF-63665039
    #$SKF-923916
    #$SKF-41511095
    #$SKF-402998
    #$SKF-1827166
    #$SKF-25558723
    #$SKF-92235
    #$SKF-24405989
    #$SKF-37741853
    #$SKF-681210
    #$SKF-16612795
    #$SKF-55392675
    #$SKF-41395088
    #$SKF-427687
    #$SKF-46187940
    #$SKF-18860364
    #$SKF-846216
    #$SKF-5393361
    #$SKF-12316220
    #$SKF-54217404
    #$SKF-5169399
    #$SKF-920133
    #$SKF-3247485
    #$SKF-2269494
    #$SKF-13038949
    #$SKF-28759634
    #$SKF-17122972
    #$SKF-953550
    #$SKF-906137
    #$SKF-14962533
    #$SKF-8254998
    #$SKF-46599863
    #$SKF-36778441
    #$SKF-45777401
    #$SKF-45356858
    #$SKF-28542904
    #$SKF-33462840
    #$SKF-18834377
    #$SKF-23165858
    #$SKF-171447
    #$SKF-38743072
    #$SKF-62752838
    #$SKF-46799967
    #$SKF-38741805
    #$SKF-22034341
    #$SKF-49949893
    #$SKF-750835
    #$SKF-27330810
    #$SKF-61593935
    #$SKF-29534329
    #$SKF-8780298
    #$SKF-10230735
    #$SKF-28051850
    #$SKF-15346572
    #$SKF-38351646
    #$SKF-54477051
    #$SKF-58577410
    #$SKF-41179398
    #$SKF-9098087
    #$SKF-464896
    #$SKF-13765056
    #$SKF-54796118
    #$SKF-892012
    #$SKF-5733810632
    #$SKF-9732365118
    #$SKF-8062776921
    #$SKF-9356282252
    #$SKF-7770326773
    #$SKF-9303451156
    #$SKF-7682359700
    #$SKF-0472592080
    #$SKF-5868767078
    #$SKF-6969827182
    #$SKF-8235654414
    #$SKF-9268693067
    #$SKF-4188164665
    #$SKF-3268848892
    #$SKF-3954038304
    #$SKF-8411301306
    #$SKF-6870027660
    #$SKF-2200319382
    #$SKF-8663443543
    #$SKF-6270260084
    #$SKF-7428624994
    #$SKF-6367907452
    #$SKF-7752915649
    #$SKF-4786775108
    #$SKF-5640043419
    #$SKF-6071218505
    #$SKF-3183844767
    #$SKF-7356970316
    #$SKF-4272845489
    #$SKF-5224425512
    #$SKF-3795912959
    #$SKF-7714022869
    #$SKF-8565886278
    #$SKF-0519624184
    #$SKF-4286299680
    #$SKF-3516286017
    #$SKF-8782865500
    #$SKF-4515155650
    #$SKF-5391096127
    #$SKF-8826617065
    #$SKF-6950497514
    #$SKF-4751258604
    #$SKF-3616130689
    #$SKF-7131788917
    #$SKF-4848573733
    #$SKF-2401054776
    #$SKF-0985467323))

(defparameter *target-consequent-literal-count* :uninitialized)

;;; Functions (ordered per declare_skolems_file)

;; (defun reify-skolems-in (arg0 arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun canonicalize-fns-in-sk-term (arg0) ...) -- no body, commented declareFunction
;; (defun subst-skolem-in (arg0 arg1 arg2) ...) -- active declareFunction, no body
;; (defun skolem-function-dependent-vars (arg0) ...) -- active declareFunction, no body
;; (defun skolem-function-var (arg0) ...) -- active declareFunction, no body
;; (defun skolem-args (arg0 arg1 arg2) ...) -- no body, commented declareFunction
;; (defun canonicalize-skolem-term (arg0 arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun replace-unreified-skolem-terms-with-variables (arg0) ...) -- no body, commented declareFunction
;; (defun lookup-sk-constant-from-defns (arg0 arg1 arg2) ...) -- no body, commented declareFunction
;; (defun defn-unreified-sk-term (arg0 arg1 arg2) ...) -- no body, commented declareFunction
;; (defun skolem-collection (arg0) ...) -- no body, commented declareFunction
;; (defun create-skolem (arg0 arg1 arg2 arg3 arg4) ...) -- no body, commented declareFunction
;; (defun sk-defn-from-clauses (arg0 arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun alpha-sort-clauses (arg0) ...) -- no body, commented declareFunction
;; (defun rename-skolem-clause-vars (arg0 arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun sk-defn-var () ...) -- no body, commented declareFunction
;; (defun clear-formula-constant-str () ...) -- no body, commented declareFunction
;; (defun remove-formula-constant-str (arg0) ...) -- no body, commented declareFunction
;; (defun formula-constant-str-internal (arg0) ...) -- no body, commented declareFunction
;; (defun formula-constant-str (arg0) ...) -- no body, commented declareFunction
;; (defun cyc-var-except-for-x-0? (arg0) ...) -- no body, commented declareFunction
;; (defun make-sk-defn (arg0 arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun sk-arity (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun make-unreified-sk-nat (arg0 arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun skolem-defn (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-defn&key (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-defn-key (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-of-defn (arg0) ...) -- active declareFunction, no body
;; (defun unreified-sk-term (arg0) ...) -- active declareFunction, no body
;; (defun skolem-defn-mt (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-seqvar (arg0) ...) -- active declareFunction, no body
;; (defun skolem-defn-seqvar (arg0) ...) -- active declareFunction, no body
;; (defun old-format-skolem? (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-number (arg0) ...) -- active declareFunction, no body
;; (defun skolem-defn-number (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-defn-args (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-var (arg0) ...) -- active declareFunction, no body
;; (defun el-unreified-sk-term (arg0) ...) -- no body, commented declareFunction
;; (defun compute-unreified-sk-term-via-hl (arg0) ...) -- no body, commented declareFunction
;; (defun compute-skolem-info-from-assertions (arg0 arg1) ...) -- no body, commented declareFunction
;; (defun skolem-table-key-from-defn (arg0) ...) -- active declareFunction, no body
;; (defun skolem-table-key-from-constant (arg0) ...) -- active declareFunction, no body
;; (defun skolem-hash-key (arg0 arg1) ...) -- active declareFunction, no body
;; (defun opaquify-unreified-skolem-terms (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-defns-from-key-specification (arg0 arg1) ...) -- active declareFunction, no body
;; (defun cnfs-of-skolem-defn (arg0) ...) -- no body, commented declareFunction
;; (defun mt-of-skolem-defn (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-defn-cnfs (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-defn-assertions-robust (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun skolem-function-has-no-defn-assertions-robust? (arg0) ...) -- active declareFunction, no body
;; (defun skolem-function-has-no-defn-assertions? (arg0) ...) -- active declareFunction, no body
;; (defun skolem-defining-bookkeeping-assertion (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-defn-assertions (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun skolems-defn-assertions (arg0) ...) -- active declareFunction, no body
;; (defun skolem-defn-siblings (arg0) ...) -- active declareFunction, no body
;; (defun skolem-defn-proper-siblings (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-canonical-sibling (arg0) ...) -- no body, commented declareFunction
;; (defun skolems-min-mt (arg0) ...) -- active declareFunction, no body
;; (defun skolem-only-mentioned-in-el-templates? (arg0 arg1) ...) -- active declareFunction, no body
;; (defun skolem-defn-assertion? (arg0 arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun gaf-has-corresponding-cnf-in-skolem-defn? (arg0 arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun constant-denoting-reified-skolem-fn? (arg0) ...) -- no body, commented declareFunction
;; (defun computed-skolem-assertion? (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-defining-assertion? (arg0) ...) -- no body, commented declareFunction
;; (defun defn-assertion-of-skolem? (arg0 arg1) ...) -- no body, commented declareFunction
;; (defun assertion-skolems (arg0) ...) -- no body, commented declareFunction
;; (defun defn-assertion-skolems (arg0) ...) -- no body, commented declareFunction
;; (defun all-skolem-mt-defn-assertions (arg0 arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun recomputing-skolem-defn-info-constant () ...) -- no body, commented declareFunction
;; (defun recomputing-skolem-defn-info-var () ...) -- no body, commented declareFunction
;; (defun really-recomputing-skolem-defn? () ...) -- no body, commented declareFunction
;; (defun recomputing-skolem-defn-info-defn () ...) -- no body, commented declareFunction
;; (defun recomputing-skolem-defn-info-key () ...) -- no body, commented declareFunction
;; (defun recomputing-skolem-defn-info-blist () ...) -- no body, commented declareFunction
;; (defun set-recomputing-skolem-defn-result (arg0 arg1) ...) -- no body, commented declareFunction
;; (defun set-recomputing-skolem-defn-blist (arg0) ...) -- no body, commented declareFunction
;; (defun recomputing-skolem-defn? () ...) -- no body, commented declareFunction
;; (defun recomputing-defn-of-skolem? (arg0) ...) -- no body, commented declareFunction
;; (defun recomputing-skolem-defn-of? (arg0) ...) -- no body, commented declareFunction
;; (defun note-skolem-binding (arg0 arg1) ...) -- no body, commented declareFunction
;; (defun recompute-skolem-defn (arg0 arg1 arg2 arg3 arg4 arg5) ...) -- no body, commented declareFunction
;; (defun remove-defn-of-skolem (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun add-skolem-defn (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun kb-skolems () ...) -- no body, commented declareFunction
;; (defun skolem-table-contains-old-format-skolems? () ...) -- active declareFunction, no body
;; (defun reset-skolem-defn-table (&optional arg0 arg1) ...) -- no body, commented declareFunction
;; (defun reset-defn-of-skolem (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun skolem-defn-from-assertions (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun reset-skolem-defn-from-assertions (arg0 &optional arg1 arg2) ...) -- no body, commented declareFunction
;; (defun skolem-variable-from-assertions (arg0 arg1) ...) -- active declareFunction, no body
;; (defun skolem-scalar-term? (arg0 &optional arg1) ...) -- active declareFunction, no body
;; (defun skolem-result-types-from-cnfs (arg0 arg1 &optional arg2 arg3) ...) -- active declareFunction, no body
;; (defun guess-skolem-result-types-from-cnfs (arg0 arg1 arg2 &optional arg3 arg4) ...) -- no body, commented declareFunction
;; (defun skolem-cnfs-pos-lit-types (arg0 arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun skolem-var-isa-constraints-wrt-cnfs (arg0 arg1 &optional arg2) ...) -- active declareFunction, no body
;; (defun skolem-var-genl-constraints-wrt-cnfs (arg0 arg1 &optional arg2) ...) -- active declareFunction, no body
;; (defun skolem-arg-isa-constraints (arg0 arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun install-skolem-arg-types (&optional arg0 arg1) ...) -- no body, commented declareFunction
;; (defun cnf-fn-argn-isa (arg0 arg1 arg2 &optional arg3) ...) -- no body, commented declareFunction
;; (defun cnf-fn-argn-var (arg0 arg1 arg2) ...) -- no body, commented declareFunction
;; (defun interpolate-arg-type (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun max-skolem-arity () ...) -- no body, commented declareFunction
;; (defun skolems-of-arity (&optional arg0) ...) -- active declareFunction, no body
;; (defun skolem-hosed? (arg0) ...) -- active declareFunction, no body
;; (defun skolem-ill-formed? (arg0) ...) -- active declareFunction, no body
;; (defun skolem-rule-hosed? (arg0 arg1) ...) -- active declareFunction, no body
;; (defun all-hosed-skolems () ...) -- no body, commented declareFunction
;; (defun multi-skolem-skolems () ...) -- no body, commented declareFunction
;; (defun misindexed-skolem-keys (&optional arg0) ...) -- no body, commented declareFunction
;; (defun sk-defns-w/o-sk-constants (&optional arg0) ...) -- no body, commented declareFunction
;; (defun sk-keys-w/o-sk-defns (&optional arg0) ...) -- no body, commented declareFunction
;; (defun install-skolemfunction-fn-in-skolem-defns (&optional arg0 arg1) ...) -- no body, commented declareFunction
;; (defun sk-defns-w/o-mts (&optional arg0) ...) -- no body, commented declareFunction
;; (defun skolem-wff? (arg0) ...) -- active declareFunction, no body
;; (defun skolem-not-wff? (arg0) ...) -- active declareFunction, no body
;; (defun why-skolem-not-wff (arg0) ...) -- active declareFunction, no body
;; (defun skolem-defn-wff? (arg0) ...) -- active declareFunction, no body
;; (defun skolem-defn-not-wff? (arg0) ...) -- no body, commented declareFunction
;; (defun why-skolem-defn-not-wff (arg0) ...) -- active declareFunction, no body
;; (defun skolem-all-good? (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-function-skolem-assertion-good? (arg0) ...) -- active declareFunction, no body
;; (defun skolem-functions-with-bad-skolem-assertions () ...) -- active declareFunction, no body
;; (defun diagnose-all-skolems () ...) -- no body, commented declareFunction
;; (defun diagnose-skolems (arg0 &optional arg1) ...) -- no body, commented declareFunction
;; (defun diagnose-skolem (arg0) ...) -- no body, commented declareFunction
;; (defun diagnose-just-this-skolem-internal (arg0) ...) -- no body, commented declareFunction
;; (defun diagnose-just-this-skolem (arg0) ...) -- no body, commented declareFunction
;; (defun recanonicalize-skolem-defn-assertions (arg0) ...) -- no body, commented declareFunction
;; (defun skolem-safe-to-recanonicalize-at-el? (arg0) ...) -- active declareFunction, no body
;; (defun compute-target-consequent-literal-count (arg0) ...) -- no body, commented declareFunction
;; (defun conjunction-of-literals? (arg0) ...) -- no body, commented declareFunction
;; (defun modernize-skolem-axiom-table () ...) -- no body, commented declareFunction
;; (defun possibly-modernize-unreified-sk-term (arg0) ...) -- no body, commented declareFunction
;; (defun skolems-with-mismatched-unreified-sk-terms () ...) -- active declareFunction, no body
;; (defun skolem-unreified-sk-terms-match? (arg0) ...) -- active declareFunction, no body
;; (defun possibly-nrepair-skolems-with-duplicate-vars (arg0) ...) -- no body, commented declareFunction
;; (defun possibly-nrepair-skolem-with-duplicate-vars (arg0) ...) -- no body, commented declareFunction
;; (defun nrepair-skolem-with-duplicate-vars (arg0) ...) -- no body, commented declareFunction
;; (defun possibly-nrepair-skolems-with-malformed-numbers (arg0) ...) -- no body, commented declareFunction
;; (defun possibly-nrepair-skolem-with-malformed-numbers (arg0) ...) -- no body, commented declareFunction
;; (defun nrepair-skolem-with-malformed-numbers (arg0) ...) -- no body, commented declareFunction
;; (defun tmi-skolem? (arg0) ...) -- active declareFunction, no body
;; (defun recanonicalize-tmi-skolems (arg0) ...) -- no body, commented declareFunction
;; (defun recanonicalize-tmi-skolem (arg0) ...) -- no body, commented declareFunction
;; (defun possibly-rehabilitate-skolem-defn-table () ...) -- no body, commented declareFunction

;;; Setup

(toplevel
  (note-globally-cached-function 'formula-constant-str)
  (note-memoized-function 'diagnose-just-this-skolem))
