!
! Copyright (C) 2001 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
subroutine ortho  
  !
#include "machine.h"
  !
  ! orthonormalize the old wavefunctions with the new S matrix, it must be
  ! after any move of atoms and only if the US problem is solved with
  ! overlap=.false.
  !
  use pwcom  
  use becmod
  use allocate 
  implicit none
  integer :: ik  

  complex(kind=DP), pointer :: sevc (:,:), dummy (:,:)  

  call mallocate(sevc , npwx , nbnd)  
  call mallocate(dummy, npwx , nbnd)  
  call setv (2 * npwx * nbnd, 0.d0, sevc, 1)  

  call setv (2 * npwx * nbnd, 0.d0, dummy, 1)  
  if (nks.gt.1) rewind (iunigk)  
  do ik = 1, nks  
     if (nks.gt.1) read (iunigk) npw, igk  
     !
     ! read the wavefunctions
     !
     call davcio (evc, nwordwfc, iunwfc, ik, - 1)  
     !
     ! calculate becp
     !
     call init_us_2 (npw, igk, xk (1, ik), vkb)  

     call ccalbec (nkb, npwx, npw, nbnd, becp, vkb, evc)  
     !
     !  find S|psi> with the new "moved" S
     !
     call s_psi (npwx, npw, nbnd, evc, sevc)  
     !
     !  orthonormalize
     !
     call cgramg1 (npwx, nbndx, npw, 1, nbnd, evc, sevc, dummy)  
     !
     !  now <psi_i|S|psi_j> = delta_ij; write the wavefunctions on file
     !
     call davcio (evc, nwordwfc, iunwfc, ik, 1)  

  enddo
  call mfree (sevc)  
  call mfree (dummy)  
  return  
end subroutine ortho

