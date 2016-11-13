!
! Copyright (C) 2001-2011 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!----------------------------------------------------------------------------
SUBROUTINE hinit1()
  !----------------------------------------------------------------------------
  !
  ! ... Atomic configuration dependent hamiltonian initialization
  !
  USE ions_base,     ONLY : nat, nsp, ityp, tau
  USE cell_base,     ONLY : at, bg, omega, tpiba2
  USE fft_base,      ONLY : dfftp
  USE gvect,         ONLY : ngm, g
  USE gvecs,         ONLY : doublegrid
  USE ldaU,          ONLY : lda_plus_u
  USE lsda_mod,      ONLY : nspin
  USE scf,           ONLY : vrs, vltot, v, kedtau
  USE control_flags, ONLY : tqr
  USE realus,        ONLY : qpointlist
  USE wannier_new,   ONLY : use_wannier
  USE martyna_tuckerman, ONLY : tag_wg_corr_as_obsolete
  USE scf,           ONLY : rho
  USE paw_variables, ONLY : okpaw, ddd_paw
  USE paw_onecenter, ONLY : paw_potential
  USE paw_init,      ONLY : paw_atomic_becsum
  USE paw_symmetry,  ONLY : paw_symmetrize_ddd
  USE dfunct,        ONLY : newd
  !
  IMPLICIT NONE
  !
  !
  ! ... update the wavefunctions, charge density, potential
  ! ... update_pot initializes structure factor array as well
  !
  CALL update_pot()
  !
  ! ... calculate the total local potential
  !
  CALL setlocal()
  !
  ! ... define the total local potential (external+scf)
  !
  CALL set_vrs( vrs, vltot, v%of_r, kedtau, v%kin_r, dfftp%nnr, nspin, doublegrid )
  !
  IF ( tqr ) CALL qpointlist()
  !
  ! ... update the D matrix and the PAW coefficients
  !
  IF (okpaw) THEN
!     CALL paw_atomic_becsum()
     CALL compute_becsum(.true.)
     CALL PAW_potential(rho%bec, ddd_paw)
     CALL PAW_symmetrize_ddd(ddd_paw)
  ENDIF
  ! 
  CALL newd()
  !
  ! ... and recalculate the products of the S with the atomic wfcs used 
  ! ... in LDA+U calculations
  !
  IF ( lda_plus_u .OR. use_wannier ) CALL orthoatwfc()
  !
  call tag_wg_corr_as_obsolete
  !
  RETURN
  !
END SUBROUTINE hinit1

