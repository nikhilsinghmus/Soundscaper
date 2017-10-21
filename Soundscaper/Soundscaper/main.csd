<CsoundSynthesizer>
<CsOptions>
</CsOptions>
<CsInstruments>

sr = 44100
ksmps = 128
nchnls = 2
0dbfs = 1

gkindex init 0

instr 1
S_ampchan sprintfk "amp%d", gkindex
kamp chnget S_ampchan

kpitcharr[] fillarray 0, 2, 3, 7, 8, 12
ktrig metro 2
schedkwhen ktrig, 0.1, 4, 10, 0, .5, kpitcharr[gkindex] + 60, kamp * 0.5

gkindex += 1

if gkindex >= lenarray(kpitcharr) then
gkindex = 0
endif

endin

instr 10
aenv expsegr 1, p3, .001
asig poscil p5*aenv, cpsmidinn(p4), 2
outs asig, asig
endin

</CsInstruments>
<CsScore>
f0 z
f2 0 16384 10 1 .5 .3333 .25 .2 .17 .14 .125
i1 0 -1
</CsScore>
</CsoundSynthesizer>
<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>100</x>
 <y>100</y>
 <width>320</width>
 <height>240</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>255</r>
  <g>255</g>
  <b>255</b>
 </bgcolor>
</bsbPanel>
<bsbPresets>
</bsbPresets>
