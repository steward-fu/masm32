; #########################################################################
;
;                             FpuArctanh
;
;##########################################################################

  ; -----------------------------------------------------------------------
  ; This procedure was written by Raymond Filiatreault, December 2002
  ; Modified March 2004 to avoid any potential data loss from the FPU
  ; Revised January 2005 to free the FPU st7 register if necessary.
  ;
  ;         atanh(Src) = 0.5 * ln[(1+Src)/(1-Src)] -> Dest
  ;
  ; This FpuArctanh function computes the number corresponding to the
  ; hyperbolic tangent value provided in the source parameter (Src) and
  ; returns the result as an 80-bit REAL number at the specified destination
  ; (the FPU itself or a memory location), unless an invalid operation is
  ; reported by the FPU or the definition of the parameters (with uID) is
  ; invalid.
  ;
  ; The source can be an 80-bit REAL number from the FPU itself or from
  ; memory. The absolute value of the source must be lower than 1,
  ; otherwise an invalid operation is reported.
  ;
  ; The source is not checked for validity. This is the programmer's
  ; responsibility.
  ;
  ; Only EAX is used to return error or success. All other CPU registers
  ; are preserved.
  ;
  ; IF a source is specified to be the FPU top data register, it would be
  ; removed from the FPU. It would be replaced by the result only if the
  ; FPU is specified as the destination.
  ;
  ; IF source data is only from memory
  ; AND the FPU is specified as the destination for the result,
  ;       the st7 data register will become the st0 data register where the
  ;       result will be returned (any valid data in that register would
  ;       have been trashed).
  ;
  ; -----------------------------------------------------------------------

    .386
    .model flat, stdcall  ; 32 bit memory model
    option casemap :none  ; case sensitive

    include Fpu.inc

    .code

; #########################################################################

FpuArctanh proc public lpSrc:DWORD, lpDest:DWORD, uID:DWORD
        
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;
; Because a library is assembled before its functions are called, all
; references to external memory data must be qualified for the expected
; size of that data so that the proper code is generated.
;
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

LOCAL content[108] :BYTE
LOCAL tempst       :TBYTE

      test  uID,SRC1_FPU      ;is Src taken from FPU?
      jz    continue

;-------------------------------
;check if top register is empty
;-------------------------------

      fxam                    ;examine its content
      fstsw ax                ;store results in AX
      fwait                   ;for precaution
      sahf                    ;transfer result bits to CPU flag
      jnc   continue          ;not empty if Carry flag not set
      jpe   continue          ;not empty if Parity flag set
      jz    srcerr1           ;empty if Zero flag set

continue:
      fsave content

;----------------------------------------
;check source for Src and load it to FPU
;----------------------------------------

      test  uID,SRC1_FPU      ;is Src taken from FPU?
      jz    @F
      lea   eax,content
      fld   tbyte ptr[eax+28]
      jmp   dest0             ;go complete process
      
   @@:
      test  uID,SRC1_REAL     ;is Src an 80-bit REAL in memory?
      jnz   @F                ;last valid ID of source

srcerr:
      frstor content
srcerr1:
      xor   eax,eax
      ret

   @@:
      mov   eax,lpSrc
      fld   tbyte ptr[eax]

dest0:
      fld   st(0)             ;copy it
      fld1
      fadd                    ;1+Src
      fxch
      fld1
      fsubr                   ;1-Src
      fdiv                    ;(1+Src)/(1-Src)
      fldln2                  ;->ln(2)=1/[log2(e)]
      fxch
      fyl2x                   ;->[log2((1+Src)/(1-Src))]/[log2(e)]
                              ; = ln[(1+Src)/(1-Src)]
      fld1
      fchs
      fxch
      fscale                  ;->0.5*ln[(1+Src)/(1-Src)] = atanh(Src)
      fstp  st(1)             ;store over scaling factor  

      fstsw ax                ;retrieve exception flags from FPU
      fwait
      shr   eax,1             ;test for invalid operations
      jc    srcerr            ;clean-up and return error

      test  uID,DEST_FPU      ;check where result should be stored
      jnz   @F                ;destination is the FPU
      mov   eax,lpDest
      fstp  tbyte ptr[eax]    ;store result at specified address
      jmp   restore
   @@:
      fstp  tempst            ;store it temporarily

restore:
      frstor  content         ;restore all previous FPU registers

      test  uID,SRC1_FPU      ;was any data taken from FPU?
      jz    @F
      fstp  st                ;remove source

   @@:
      test  uID,DEST_FPU
      jz    @F                ;the new value has been stored in memory
                              ;none of the FPU data was modified

      ffree st(7)             ;free it if not already empty
      fld   tempst            ;load the new value on the FPU
   @@:
      or    al,1              ;to insure EAX!=0
      ret
    
FpuArctanh endp

; #########################################################################

end
