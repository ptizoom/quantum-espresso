!
! Copyright (C) 2001-2004 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
#include "machine.h"
!
!----------------------------------------------------------------------------
SUBROUTINE c_bands( iter, ik_, dr2 )
  !----------------------------------------------------------------------------
  !
  ! ... this is a wrapper to specific calls
  !
  ! ... internal procedures :
  !
  ! ... c_bands_gamma()   : for gamma sampling of the BZ (optimized algorithms)
  ! ... c_bands_k()       : for arbitrary BZ sampling (general algorithm)
  ! ... test_exit_cond()  : the test on the iterative diagonalization
  !
  !
  USE kinds,                ONLY : DP
  USE constants,            ONLY : eps4
  USE io_global,            ONLY : stdout
  USE wvfct,                ONLY : gamma_only
  USE io_files,             ONLY : iunigk, nwordatwfc, iunat, iunwfc, nwordwfc
  USE cell_base,            ONLY : tpiba2 
  USE klist,                ONLY : nkstot, nks, xk, nelec
  USE us,                   ONLY : okvan
  USE uspp,                 ONLY : vkb, nkb
  USE gvect,                ONLY : g, gstart, ecfixed, qcutz, q2sigma, nrxx, &
                                   nr1, nr2, nr3  
  USE wvfct,                ONLY : g2kin, wg, nbndx, et, nbnd, npwx, igk, &
                                   npw
  USE control_flags,        ONLY : diis_ndim, istep, ethr, lscf, max_cg_iter, &
                                   diis_ethr_cg, isolve, reduce_io
  USE ldaU,                 ONLY : lda_plus_u, swfcatom
  USE scf,                  ONLY : vltot
  USE lsda_mod,             ONLY : current_spin, lsda, isk
  USE wavefunctions_module, ONLY : evc  
  USE g_psi_mod,            ONLY : h_diag, s_diag
  USE diis_module,          ONLY : cdiisg, rdiisg
  !
  IMPLICIT NONE
  !
  ! ... First the I/O variables
  !
  INTEGER :: ik_, iter
    ! k-point already done
    ! current iterations
  REAL(KIND=DP) :: dr2
    ! current accuracy of self-consistency
  !
  ! ... local variables
  !
  REAL(KIND=DP) :: avg_iter, v_of_0
    ! average number of iterations
    ! the average of the potential
  INTEGER :: ik, ig, ibnd, dav_iter, diis_iter, ntry, notconv
    ! counter on k points
    ! counter on G vectors
    ! counter on bands
    ! number of iterations in Davidson
    ! number of iterations in DIIS
    ! number or repeated call to diagonalization in case of non convergence
    ! number of notconverged elements
  INTEGER, ALLOCATABLE :: btype(:)
    ! type of band: conduction (1) or valence (0)  
  !
  ! ... external functions
  !
  REAL(KIND=DP), EXTERNAL :: erf
    ! error function  
  !
  !
  CALL start_clock( 'c_bands' )
  !
  IF ( ik_ == nks ) THEN
     !
     ik_ = 0
     !
     RETURN
     !
  END IF
  !
  ! ... allocate arrays
  !
  ALLOCATE( h_diag( npwx ) )    
  ALLOCATE( s_diag( npwx ) )   
  !
  ! ... allocate specific array for DIIS
  !
  IF ( isolve == 2 ) ALLOCATE( btype(  nbnd ) )       
  !
  IF ( gamma_only ) THEN
     !
     CALL c_bands_gamma()
     !
  ELSE
     !
     CALL c_bands_k()
     !
  END IF  
  !
  ! ... deallocate arrays
  !
  DEALLOCATE( s_diag )
  DEALLOCATE( h_diag )
  !
  IF ( isolve == 2 ) DEALLOCATE( btype )
  !       
  CALL stop_clock( 'c_bands' )  
  !
  RETURN
  !
  CONTAINS
     !
     ! ... internal procedures
     !
     !-----------------------------------------------------------------------
     SUBROUTINE c_bands_gamma()
       !-----------------------------------------------------------------------
       !  
       ! ... This routine is a driver for the diagonalization routines of the
       ! ... total Hamiltonian at Gammma point only
       ! ... It reads the Hamiltonian and an initial guess of the wavefunctions
       ! ... from a file and computes initialization quantities for the
       ! ... diagonalization routines.
       ! ... There are two types of iterative diagonalization:
       ! ... a) Davidson algorithm (all-band)
       ! ... c) DIIS algorithm (all-band) 
       !
       USE becmod, ONLY: rbecp
       !
       IMPLICIT NONE
       !     
       !
       ! ... rbecp contains <beta|psi> - used in h_psi and s_psi
       !
       ALLOCATE( rbecp( nkb, nbnd ) )
       !
       IF ( isolve == 0 ) THEN
          !
          WRITE( stdout, '(5X,"Davidson diagonalization with overlap")' )
          !
       ELSE IF ( isolve == 2 ) THEN
          !
          WRITE( stdout, '(5X,"DIIS style diagonalization")')
          !       
       ELSE
          !
          CALL errore( 'c_bands', 'CG diagonalization not implemented', 1 )
          !
       END IF
       !
       avg_iter = 0.D0
       !
       ! ... v_of_0 is (Vloc)(G=0)
       !
       v_of_0 = SUM( vltot(1:nrxx) ) / REAL( nr1 * nr2 * nr3 )
       !
       CALL reduce( 1, v_of_0 )
       !
       IF ( nks > 1 ) REWIND( iunigk )
       !
       ! ... For each k point diagonalizes the hamiltonian
       !
       k_loop: DO ik = 1, nks
          !
          IF ( lsda ) current_spin = isk(ik)
          !
          ! ... Reads the Hamiltonian and the list k+G <-> G of this k point
          !
          IF ( nks > 1 ) READ( iunigk ) npw, igk
          !
          ! ... do not recalculate k-points if restored from a previous run
          !
          IF ( ik <= ik_ ) THEN
             !
             CALL save_in_cbands( iter, ik, dr2 )
             !
             CYCLE k_loop
             !
          END IF          
          !
          ! ... various initializations
          !
          IF ( nkb > 0 ) &
             CALL init_us_2( npw, igk, xk(1,ik), vkb )
          !
          ! ... read in wavefunctions from the previous iteration
          !
          IF ( nks > 1 .OR. .NOT. reduce_io ) &
             call davcio( evc, nwordwfc, iunwfc, ik, -1 )
          !
          ! ... Needed for LDA+U
          !
          IF ( lda_plus_u ) CALL davcio( swfcatom, nwordatwfc, iunat, ik, -1 )
          !
          ! ... sets the kinetic energy
          !
          g2kin(1:npw) = ( ( xk(1,ik) + g(1,igk(1:npw)) )**2 + &
                           ( xk(2,ik) + g(2,igk(1:npw)) )**2 + &
                           ( xk(3,ik) + g(3,igk(1:npw)) )**2 ) * tpiba2
          !
          IF ( qcutz > 0.D0 ) THEN
             !
             DO ig = 1, npw
                g2kin(ig) = g2kin(ig) + qcutz * &
                            ( 1.D0 + erf( (g2kin(ig) - ecfixed ) / q2sigma ) )
             END DO
             !
          END IF
          !
          IF ( isolve == 2 ) THEN
             !
             ! ... RMM-DIIS method
             !
             h_diag(1:npw) = g2kin(1:npw) + v_of_0
             !
             CALL usnldiag( h_diag, s_diag )
             !
             ntry = 0
             diis_iter = 0.D0
             !
             btype(:) = 1
             !
             IF ( iter == 1 ) THEN
                !
                ! ... at the first iteration a static criterium is used to
                ! ... define whether or not a band is occupied
                !
                FORALL( ibnd = 1 : nbnd, &
                        ibnd > ( INT( nelec / 2.D0 ) + 4 ) ) btype(ibnd) = 0
                !
             ELSE
                !
                ! ... a band is considered empty when its occupation is less 
                ! ... than 1.0 %
                !   
                WHERE( wg(:,ik) < 0.01D0 ) btype(:) = 0
                !
             END IF   
             !
             RMMDIIS_loop: DO
                !
                CALL rdiisg( npw, npwx, nbnd, diis_ndim, evc, &
                             et(:,ik), ethr, btype, notconv, diis_iter, iter )
                !  
                avg_iter = avg_iter + diis_iter
                !
                ! ... save wave-functions to be used as input for the
                ! ... iterative diagonalization of the next scf iteration 
                ! ... and for rho calculation
                !
                IF ( nks > 1 .OR. .NOT. reduce_io ) &
                   CALL davcio( evc, nwordwfc, iunwfc, ik, 1 )
                !
                ntry = ntry + 1                
                !
                ! ... exit condition
                !
                IF ( test_exit_cond() ) EXIT  RMMDIIS_loop
                !
             END DO RMMDIIS_loop
             !
          ELSE
             !
             ! ... Davidson diagonalization
             !
             ! ... h_diag are the diagonal matrix elements of the 
             ! ... hamiltonian used in g_psi to evaluate the correction 
             ! ... to the trial eigenvectors
             !
             h_diag(1:npw) = g2kin(1:npw) + v_of_0
             !
             CALL usnldiag( h_diag, s_diag )
             !
             ntry = 0
             !
             david_loop: DO
                !
                CALL regterg( npw, npwx, nbnd, nbndx, evc, ethr, &
                              okvan, gstart, et(1,ik), notconv, dav_iter )
                !
                avg_iter = avg_iter + dav_iter
                !
                ! ... save wave-functions to be used as input for the
                ! ... iterative diagonalization of the next scf iteration 
                ! ... and for rho calculation
                !
                IF ( nks > 1 .OR. .NOT. reduce_io ) &
                   CALL davcio( evc, nwordwfc, iunwfc, ik, 1 )
                !   
                ntry = ntry + 1
                !
                ! ... exit condition
                !
                IF ( test_exit_cond() ) EXIT  david_loop
                !
             END DO david_loop
             !
          END IF
          !
          IF ( notconv > MAX( 5, nbnd / 4 ) ) THEN
             !
             CALL errore( 'c_bands', &
                        & 'too many bands are not converged', 1 )
             !
          END IF
          !
          ! ... save restart information
          !
          CALL save_in_cbands( iter, ik, dr2 )
          !
       END DO k_loop
       !
       ik_ = 0
       !
       CALL poolreduce( 1, avg_iter )
       !
       avg_iter = avg_iter / nkstot
       !
       WRITE( stdout, &
              '( 5X,"ethr = ",1PE9.2,",  avg # of iterations =",0PF5.1 )' ) &
           ethr, avg_iter
       !
       ! ... deallocate work space
       !
       DEALLOCATE( rbecp )
       !
       RETURN
       !
     END SUBROUTINE c_bands_gamma  
     !
     !     
     !-----------------------------------------------------------------------
     SUBROUTINE c_bands_k()
       !-----------------------------------------------------------------------
       !
       ! ... This routine is a driver for the diagonalization routines of the
       ! ... total Hamiltonian at each k-point.
       ! ... It reads the Hamiltonian and an initial guess of the wavefunctions
       ! ... from a file and computes initialization quantities for the
       ! ... diagonalization routines.
       ! ... There are three types of iterative diagonalization:
       ! ... a) Davidson algorithm (all-band)
       ! ... b) Conjugate Gradient (band-by-band)
       ! ... c) DIIS algorithm
       !
       USE becmod, ONLY: becp
       !
       IMPLICIT NONE
       !
       ! ... here the local variables
       !
       REAL(KIND=DP) :: cg_iter
       ! number of iteration in CG
       ! number of iteration in DIIS
       !
       ! ... becp contains <beta|psi> - used in h_psi and s_psi
       !
       ALLOCATE( becp( nkb, nbnd ) )
       !
       ! ... allocate specific array for DIIS
       !
       !
       IF ( isolve == 0 ) THEN
          !
          WRITE( stdout, '(5X,"Davidson diagonalization (with overlap)")')
          !
       ELSE IF ( isolve == 1 ) THEN
          !
          WRITE( stdout, '(5X,"Conjugate-gradient style diagonalization")')
          !
       ELSE IF ( isolve == 2 ) THEN
          !
          WRITE( stdout, '(5X,"DIIS style diagonalization")')
          !
       ELSE
          !
          CALL errore( 'c_bands', 'isolve not implemented', 1 )
          !
       END IF
       !
       avg_iter = 0.D0
       !
       ! ... v_of_0 is (Vloc)(G=0)
       !
       v_of_0 = SUM( vltot(1:nrxx) ) / REAL( nr1 * nr2 * nr3 )
       !
       CALL reduce( 1, v_of_0 )
       !
       if ( nks > 1 ) REWIND( iunigk )
       !
       ! ... For each k point diagonalizes the hamiltonian
       !
       k_loop: DO ik = 1, nks
          !
          IF ( lsda ) current_spin = isk(ik)
          !
          ! ... Reads the Hamiltonian and the list k+G <-> G of this k point
          !
          IF ( nks > 1 ) READ( iunigk ) npw, igk
          !
          ! ... do not recalculate k-points if restored from a previous run
          !
          IF ( ik <= ik_ ) THEN
             !
             CALL save_in_cbands( iter, ik, dr2 )
             !
             CYCLE k_loop
             !
          END IF
          !
          ! ... various initializations
          !
          IF ( nkb > 0 ) &
             CALL init_us_2( npw, igk, xk(1,ik), vkb )
          !
          ! ... read in wavefunctions from the previous iteration
          !
          IF ( nks > 1 .OR. .NOT. reduce_io ) &
             CALL davcio( evc, nwordwfc, iunwfc, ik, -1 )
          !   
          ! ... Needed for LDA+U
          !
          IF ( lda_plus_u ) CALL davcio( swfcatom, nwordatwfc, iunat, ik, -1 )
          !
          ! ... sets the kinetic energy
          !
          g2kin(1:npw) = ( ( xk(1,ik) + g(1,igk(1:npw)) )**2 + &
                           ( xk(2,ik) + g(2,igk(1:npw)) )**2 + &
                           ( xk(3,ik) + g(3,igk(1:npw)) )**2 ) * tpiba2
          !
          !
          IF ( qcutz > 0.D0 ) THEN
             DO ig = 1, npw
                g2kin (ig) = g2kin(ig) + qcutz * &
                             ( 1.D0 + erf( ( g2kin(ig) - ecfixed ) / q2sigma ) )
             END DO
          END IF
          !
          IF ( isolve == 1 ) THEN
             !
             ! ... Conjugate-Gradient diagonalization
             !
             ! ... h_diag is the precondition matrix
             !
             h_diag(1:npw) = MAX( 1.D0, g2kin(1:npw) )
             !
             ntry = 0
             !
             CG_loop : DO
                !
                IF ( iter /= 1 .OR. istep /= 1 .OR. ntry > 0 ) THEN
                   !
                   CALL cinitcgg( npwx, npw, nbnd, nbnd, evc, evc, et(1,ik) )
                   !
                   avg_iter = avg_iter + 1.D0
                   !
                END IF
                !
                CALL ccgdiagg( npwx, npw, nbnd, evc, et(1,ik), h_diag, ethr, &
                               max_cg_iter, .not.lscf, notconv, cg_iter )
                !
                avg_iter = avg_iter + cg_iter
                !
                ! ... save wave-functions to be used as input for the
                ! ... iterative diagonalization of the next scf iteration 
                ! ... and for rho calculation
                !
                IF ( nks > 1 .OR. .NOT. reduce_io ) &
                   CALL davcio( evc, nwordwfc, iunwfc, ik, 1 )
                !
                ntry = ntry + 1                
                !
                ! ... exit condition
                !
                IF ( test_exit_cond() ) EXIT  CG_loop
                !
             END DO CG_loop
             !
          ELSE IF ( isolve == 2 ) THEN
             !
             ! ... RMM-DIIS method
             !
             h_diag(1:npw) = g2kin(1:npw) + v_of_0
             !
             CALL usnldiag( h_diag, s_diag )
             !
             ntry = 0
             diis_iter = 0.D0
             !
             btype(:) = 1
             !
             IF ( iter == 1 ) THEN
                !
                ! ... at the first iteration a static criterium is used to
                ! ... define whether or not a band is occupied
                !
                FORALL( ibnd = 1 : nbnd, &
                        ibnd > ( INT( nelec / 2.D0 ) + 4 ) ) btype(ibnd) = 0
                !
             ELSE
                !
                ! ... a band is considered empty when its occupation is less 
                ! ... than 1.0 %
                !   
                WHERE( wg(:,ik) < 0.01D0 ) btype(:) = 0
                !
             END IF   
             !
             RMMDIIS_loop: DO
                !
                CALL cdiisg( npw, npwx, nbnd, diis_ndim, evc, &
                             et(:,ik), ethr, btype, notconv, diis_iter, iter )
                !  
                avg_iter = avg_iter + diis_iter
                !
                ! ... save wave-functions to be used as input for the
                ! ... iterative diagonalization of the next scf iteration 
                ! ... and for rho calculation
                !
                IF ( nks > 1 .OR. .NOT. reduce_io ) &
                   CALL davcio( evc, nwordwfc, iunwfc, ik, 1 )
                !
                ntry = ntry + 1                
                !
                ! ... exit condition
                !
                IF ( test_exit_cond() ) EXIT  RMMDIIS_loop
                !
             END DO RMMDIIS_loop
             !
          ELSE
             !
             ! ... Davidson diagonalization
             !
             ! ... h_diag are the diagonal matrix elements of the
             ! ... hamiltonian used in g_psi to evaluate the correction 
             ! ... to the trial eigenvectors
             !
             h_diag(1:npw) = g2kin(1:npw) + v_of_0
             !
             CALL usnldiag( h_diag, s_diag )
             !
             ntry = 0
             !
             david_loop: DO
                !
                CALL cegterg( npw, npwx, nbnd, nbndx, evc, ethr, &
                              okvan, et(1,ik), notconv, dav_iter )
                !
                avg_iter = avg_iter + dav_iter
                !
                ! ... save wave-functions to be used as input for the
                ! ... iterative diagonalization of the next scf iteration 
                ! ... and for rho calculation
                !
                IF ( nks > 1 .OR. .NOT. reduce_io ) &
                   CALL davcio( evc, nwordwfc, iunwfc, ik, 1 )
                !
                ntry = ntry + 1                
                !
                ! ... exit condition
                !
                IF ( test_exit_cond() ) EXIT david_loop                
                !
             END DO david_loop
             !
          END IF
          !
          IF ( notconv > MAX( 5, nbnd / 4 ) ) THEN
             !
             CALL errore( 'c_bands', &
                        & 'too many bands are not converged', 1 )
             !
          END IF
          !
          ! ... save restart information
          !
          CALL save_in_cbands( iter, ik, dr2 )
          !
       END DO k_loop
       !
       ik_ = 0
       !
       CALL poolreduce( 1, avg_iter )
       !
       avg_iter = avg_iter / nkstot
       !
       WRITE( stdout, &
              '( 5X,"ethr = ",1PE9.2,",  avg # of iterations =",0PF5.1 )' ) &
           ethr, avg_iter
       !
       ! ... deallocate work space
       !
       DEALLOCATE( becp )
       !
       RETURN
       !
     END SUBROUTINE c_bands_k
     !
     !
     !-----------------------------------------------------------------------
     FUNCTION test_exit_cond()
       !-----------------------------------------------------------------------
       !
       ! ... this logical function is .TRUE. when iterative diagonalization
       ! ... is converged
       !
       IMPLICIT NONE
       !
       LOGICAL :: test_exit_cond
       !
       !
       test_exit_cond = .NOT. ( ( ntry <= 5 ) .AND. &
                                ( ( .NOT. lscf .AND. ( notconv > 0 ) ) .OR. &
                                  (       lscf .AND. ( notconv > 5 ) ) ) )
       !                          
     END FUNCTION test_exit_cond
     !     
END SUBROUTINE c_bands
