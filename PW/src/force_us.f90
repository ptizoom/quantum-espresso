!
! Copyright (C) 2001-2007 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!----------------------------------------------------------------------------
SUBROUTINE force_us( forcenl )
  !----------------------------------------------------------------------------
  !
  ! ... nonlocal potential contribution to forces
  ! ... wrapper
  !
  USE kinds,                ONLY : DP
  USE control_flags,        ONLY : gamma_only
  USE cell_base,            ONLY : at, bg, tpiba
  USE ions_base,            ONLY : nat, ntyp => nsp, ityp
  USE klist,                ONLY : nks, xk, ngk
  USE gvect,                ONLY : g
  USE uspp,                 ONLY : nkb, vkb, qq, deeq, qq_so, deeq_nc
  USE uspp_param,           ONLY : upf, nh, newpseudo, nhm
  USE wvfct,                ONLY : nbnd, npw, npwx, igk, wg, et
  USE lsda_mod,             ONLY : lsda, current_spin, isk, nspin
  USE symme,                ONLY : symvector
  USE wavefunctions_module, ONLY : evc
  USE noncollin_module,     ONLY : npol, noncolin
  USE spin_orb,             ONLY : lspinorb
  USE io_files,             ONLY : iunwfc, nwordwfc, iunigk
  USE buffers,              ONLY : get_buffer
  USE becmod,               ONLY : bec_type, becp, allocate_bec_type, deallocate_bec_type
  USE mp_global,            ONLY : inter_pool_comm, intra_bgrp_comm
  USE mp,                   ONLY : mp_sum, mp_get_comm_null
  !
  IMPLICIT NONE
  !
  ! ... the dummy variable
  !
  REAL(DP) :: forcenl(3,nat)
  ! output: the nonlocal contribution
  !
  CALL allocate_bec_type ( nkb, nbnd, becp, intra_bgrp_comm )   
  !
  IF ( gamma_only ) THEN
     !
     CALL force_us_gamma( forcenl )
     !
  ELSE
     !
     CALL force_us_k( forcenl )
     !
  END IF  
  !
  CALL deallocate_bec_type ( becp )   
  !
  RETURN
  !
  CONTAINS
     !
     !-----------------------------------------------------------------------
     SUBROUTINE force_us_gamma( forcenl )
       !-----------------------------------------------------------------------
       !
       ! ... calculation at gamma
       !
       USE becmod, ONLY : calbec
       IMPLICIT NONE
       !
       REAL(DP) :: forcenl(3,nat)
       TYPE(bec_type) :: rdbecp (3)
       ! auxiliary variable, contains <dbeta|psi>
       COMPLEX(DP), ALLOCATABLE :: vkb1(:,:)
       ! auxiliary variable contains g*|beta>
       REAL(DP) :: ps
       INTEGER       :: ik, ipol, ibnd, ibnd_loc, ig, ih, jh, na, nt, ikb, jkb, ijkb0
       ! counters
       !
       ! ... Important notice about parallelization over the band group of processors:
       ! ... 1) internally, "calbec" parallelises on plane waves over the band group
       ! ... 2) the results of "calbec" are distributed across processors of the band
       ! ...    group: the band index of becp, rdbecp is distributed
       ! ... 3) the band group is subsequently used to parallelize over bands
       !
       forcenl(:,:) = 0.D0
       !
       DO ipol = 1, 3
          CALL allocate_bec_type ( nkb, nbnd, rdbecp(ipol), intra_bgrp_comm )   
       END DO
       ALLOCATE( vkb1(  npwx, nkb ) ) 
       !   
       IF ( nks > 1 ) REWIND iunigk
       !
       ! ... the forces are a sum over the K points and over the bands
       !
       DO ik = 1, nks
          IF ( lsda ) current_spin = isk(ik)
          !
          npw = ngk (ik)
          IF ( nks > 1 ) THEN
             READ( iunigk ) igk
             CALL get_buffer ( evc, nwordwfc, iunwfc, ik )
             IF ( nkb > 0 ) &
                CALL init_us_2( npw, igk, xk(1,ik), vkb )
          END IF
          !
          CALL calbec ( npw, vkb, evc, becp )
          !
          DO ipol = 1, 3
             DO jkb = 1, nkb
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(ig)
                DO ig = 1, npw
                   vkb1(ig,jkb) = vkb(ig,jkb) * (0.D0,-1.D0) * g(ipol,igk(ig))
                END DO
!$OMP END PARALLEL DO
             END DO
             !
             CALL calbec ( npw, vkb1, evc, rdbecp(ipol) )
             !
          END DO
          !
          ! ... from now on, sums over bands are parallelized over the band group
          !
          ijkb0 = 0
          DO nt = 1, ntyp
             DO na = 1, nat
                IF ( ityp(na) == nt ) THEN
                   DO ih = 1, nh(nt)
                      ikb = ijkb0 + ih
                      DO ibnd_loc = 1, becp%nbnd_loc
                         ibnd = ibnd_loc + becp%ibnd_begin - 1
                         ps = deeq(ih,ih,na,current_spin) - &
                              et(ibnd,ik) * qq(ih,ih,nt)
                         DO ipol = 1, 3
                            forcenl(ipol,na) = forcenl(ipol,na) - &
                                       ps * wg(ibnd,ik) * 2.D0 * tpiba * &
                                       rdbecp(ipol)%r(ikb,ibnd_loc) *becp%r(ikb,ibnd_loc)
                         END DO
                      END DO
                      !
                      IF ( upf(nt)%tvanp .OR. newpseudo(nt) ) THEN
                         !
                         ! ... in US case there is a contribution for jh<>ih. 
                         ! ... We use here the symmetry in the interchange 
                         ! ... of ih and jh
                         !
                         DO jh = ( ih + 1 ), nh(nt)
                            jkb = ijkb0 + jh
                            DO ibnd_loc = 1, becp%nbnd_loc
                               ibnd = ibnd_loc + becp%ibnd_begin - 1
                               ps = deeq(ih,jh,na,current_spin) - &
                                    et(ibnd,ik) * qq(ih,jh,nt)
                               DO ipol = 1, 3
                                  forcenl(ipol,na) = forcenl(ipol,na) - &
                                     ps * wg(ibnd,ik) * 2.d0 * tpiba * &
                                     (rdbecp(ipol)%r(ikb,ibnd_loc) *becp%r(jkb,ibnd_loc) + &
                                      rdbecp(ipol)%r(jkb,ibnd_loc) *becp%r(ikb,ibnd_loc) )
                               END DO
                            END DO
                         END DO
                      END IF
                   END DO
                   ijkb0 = ijkb0 + nh(nt)
                END IF
             END DO
          END DO
       END DO
       !
       IF( becp%comm /= mp_get_comm_null() ) CALL mp_sum( forcenl, becp%comm )
       !
       DEALLOCATE( vkb1 )
       DO ipol = 1, 3
          CALL deallocate_bec_type ( rdbecp(ipol) )   
       END DO
       !
       ! ... The total D matrix depends on the ionic position via the
       ! ... augmentation part \int V_eff Q dr, the term deriving from the 
       ! ... derivative of Q is added in the routine addusforce
       !
       CALL addusforce( forcenl )
       !
       ! ... collect contributions across pools (sum over k-points)
       !
       CALL mp_sum( forcenl, inter_pool_comm )
       !
       ! ... Since our summation over k points was only on the irreducible 
       ! ... BZ we have to symmetrize the forces
       !
       CALL symvector ( nat, forcenl )
       !
       RETURN
       !
     END SUBROUTINE force_us_gamma
     !     
     !-----------------------------------------------------------------------
     SUBROUTINE force_us_k( forcenl )
       !-----------------------------------------------------------------------
       !  
       USE becmod, ONLY : calbec
       IMPLICIT NONE
       !
       REAL(DP) :: forcenl(3,nat)
       COMPLEX(DP), ALLOCATABLE :: dbecp(:,:,:), dbecp_nc(:,:,:,:)
       ! auxiliary variable contains <beta|psi> and <dbeta|psi>
       COMPLEX(DP), ALLOCATABLE :: vkb1(:,:)
       ! auxiliary variable contains g*|beta>
       COMPLEX(DP) :: psc(2,2), fac
       COMPLEX(DP), ALLOCATABLE :: deff_nc(:,:,:,:)
       REAL(DP), ALLOCATABLE :: deff(:,:,:)
       REAL(DP) :: ps
       INTEGER       :: ik, ipol, ibnd, ig, ih, jh, na, nt, ikb, jkb, ijkb0, &
                        is, js, ijs
       ! counters
       !
       !
       forcenl(:,:) = 0.D0
       !
       IF (noncolin) then
          ALLOCATE( dbecp_nc(nkb,npol,nbnd,3) )
          ALLOCATE( deff_nc(nhm,nhm,nat,nspin) )
       ELSE
          ALLOCATE( dbecp( nkb, nbnd, 3 ) )    
          ALLOCATE( deff(nhm,nhm,nat) )
       ENDIF
       ALLOCATE( vkb1( npwx, nkb ) )   
       ! 
       IF ( nks > 1 ) REWIND iunigk
       !
       ! ... the forces are a sum over the K points and the bands
       !
       DO ik = 1, nks
          IF ( lsda ) current_spin = isk(ik)
          !
          npw = ngk(ik)
          IF ( nks > 1 ) THEN
             READ( iunigk ) igk
             CALL get_buffer ( evc, nwordwfc, iunwfc, ik )
             IF ( nkb > 0 ) &
                CALL init_us_2( npw, igk, xk(1,ik), vkb )
          END IF
          !
          CALL calbec ( npw, vkb, evc, becp)
          !
          DO ipol = 1, 3
             DO jkb = 1, nkb
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(ig)
                DO ig = 1, npw
                   vkb1(ig,jkb) = vkb(ig,jkb)*(0.D0,-1.D0)*g(ipol,igk(ig))
                END DO
!$OMP END PARALLEL DO
             END DO
             !
             IF (noncolin) THEN
                IF ( nkb > 0 ) &
                   CALL ZGEMM( 'C', 'N', nkb, nbnd*npol, npw, ( 1.D0, 0.D0 ),&
                            vkb1, npwx, evc, npwx, ( 0.D0, 0.D0 ),    &
                            dbecp_nc(1,1,1,ipol), nkb )
             ELSE
                IF ( nkb > 0 ) &
                   CALL ZGEMM( 'C', 'N', nkb, nbnd, npw, ( 1.D0, 0.D0 ),   &
                            vkb1, npwx, evc, npwx, ( 0.D0, 0.D0 ),      &
                            dbecp(1,1,ipol), nkb )
             END IF
          END DO
          !
          DO ibnd = 1, nbnd
             IF (noncolin) THEN
                CALL compute_deff_nc(deff_nc,et(ibnd,ik))
             ELSE
                CALL compute_deff(deff,et(ibnd,ik))
             ENDIF
             fac=wg(ibnd,ik)*tpiba
             ijkb0 = 0
             DO nt = 1, ntyp
                DO na = 1, nat
                   IF ( ityp(na) == nt ) THEN
                      DO ih = 1, nh(nt)
                         ikb = ijkb0 + ih
                         IF (noncolin) THEN
                            DO ipol=1,3
                               ijs=0
                               DO is=1,npol
                                  DO js=1,npol
                                     ijs=ijs+1
                                     forcenl(ipol,na) = forcenl(ipol,na)- &
                                         deff_nc(ih,ih,na,ijs)*fac*( &
                                         CONJG(dbecp_nc(ikb,is,ibnd,ipol))* &
                                         becp%nc(ikb,js,ibnd)+ &
                                         CONJG(becp%nc(ikb,is,ibnd))* &
                                         dbecp_nc(ikb,js,ibnd,ipol) )
                                  END DO
                               END DO
                            END DO
                         ELSE
                            DO ipol=1,3
                               forcenl(ipol,na) = forcenl(ipol,na) - &
                                  2.D0 * fac * deff(ih,ih,na)*&
                                      DBLE( CONJG( dbecp(ikb,ibnd,ipol) ) * &
                                            becp%k(ikb,ibnd) )
                            END DO
                         END IF
                         !
                         IF ( upf(nt)%tvanp .OR. newpseudo(nt) ) THEN
                         !
                         ! ... in US case there is a contribution for jh<>ih. 
                         ! ... We use here the symmetry in the interchange 
                         ! ... of ih and jh
                         !
                            DO jh = ( ih + 1 ), nh(nt)
                               jkb = ijkb0 + jh
                               IF (noncolin) THEN
                                  DO ipol=1,3
                                     ijs=0
                                     DO is=1,npol
                                        DO js=1,npol
                                           ijs=ijs+1
                                           forcenl(ipol,na)=forcenl(ipol,na)- &
                                           deff_nc(ih,jh,na,ijs)*fac*( &
                                          CONJG(dbecp_nc(ikb,is,ibnd,ipol))* &
                                                 becp%nc(jkb,js,ibnd)+ &
                                          CONJG(becp%nc(ikb,is,ibnd))* &
                                                dbecp_nc(jkb,js,ibnd,ipol))- &
                                           deff_nc(jh,ih,na,ijs)*fac*( &
                                          CONJG(dbecp_nc(jkb,is,ibnd,ipol))* &
                                                becp%nc(ikb,js,ibnd)+ &
                                          CONJG(becp%nc(jkb,is,ibnd))* &
                                                dbecp_nc(ikb,js,ibnd,ipol) )
                                        END DO
                                     END DO
                                  END DO
                               ELSE
                                  DO ipol = 1, 3
                                     forcenl(ipol,na) = forcenl (ipol,na) - &
                                          2.D0 * fac * deff(ih,jh,na)* &
                                       DBLE( CONJG( dbecp(ikb,ibnd,ipol) ) * &
                                             becp%k(jkb,ibnd) +       &
                                             dbecp(jkb,ibnd,ipol) * &
                                             CONJG( becp%k(ikb,ibnd) ) )
                                  END DO
                               END IF
                            END DO !jh
                         END IF ! tvanp
                      END DO ! ih = 1, nh(nt)
                      ijkb0 = ijkb0 + nh(nt)
                   END IF ! ityp(na) == nt
                END DO ! nat
             END DO ! ntyp
          END DO ! nbnd
       END DO ! nks
       !
       CALL mp_sum(  forcenl , intra_bgrp_comm )
       !
       DEALLOCATE( vkb1 )
       IF (noncolin) THEN
          DEALLOCATE( dbecp_nc )
          DEALLOCATE( deff_nc )
       ELSE
          DEALLOCATE( dbecp )
          DEALLOCATE( deff )
       ENDIF
       !
       ! ... The total D matrix depends on the ionic position via the
       ! ... augmentation part \int V_eff Q dr, the term deriving from the 
       ! ... derivative of Q is added in the routine addusforce
       !
       CALL addusforce( forcenl )
       !
       !
       ! ... collect contributions across pools
       !
       CALL mp_sum( forcenl, inter_pool_comm )
       !
       ! ... Since our summation over k points was only on the irreducible 
       ! ... BZ we have to symmetrize the forces.
       !
       CALL symvector ( nat, forcenl )
       !
       RETURN
       !
     END SUBROUTINE force_us_k
     !     
END SUBROUTINE force_us
