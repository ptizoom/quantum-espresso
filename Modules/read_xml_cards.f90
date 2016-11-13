!
!
!-------------------------------------------------------------!
! This module handles the cards reading in case of xml input  !
!                                                             !
!   written by Simone Ziraldo (08/2010)                       !
!-------------------------------------------------------------!
!
! cards not yet implemented:
! KSOUT
! AUTOPILOT
! ATOMIC_FORCES
! PLOT_WANNIER
! WANNIER_AC
! DIPOLE
! ESR
!
! to implement these cards take inspiration from file read_cards.f90
!
MODULE read_xml_cards_module
  !
  !
  USE io_global, ONLY : xmlinputunit
  USE iotk_module, ONLY : iotk_scan_begin, iotk_scan_end, iotk_scan_dat,&
       iotk_scan_dat_inside, iotk_scan_attr, iotk_attlenx
  USE read_xml_fields_module, ONLY : clean_str
  USE kinds, ONLY : DP
  !
  USE io_global, ONLY : stdout
  !
  USE input_parameters
  !
  !
  IMPLICIT NONE
  !
  SAVE
  !
  PRIVATE
  !
  PUBLIC :: card_xml_atomic_species, card_xml_atomic_list, card_xml_chain, card_xml_cell, &
       card_xml_kpoints, card_xml_occupations, card_xml_constraints, card_xml_climbing_images, &
       card_xml_plot_wannier, card_default, card_bcast
  !
  !
  !
CONTAINS
  !
  !
  !--------------------------------------------------------------------------!
  !   This subroutine sets all the cards default value; as an input          !
  !   takes the card name that you want to set                               !
  !--------------------------------------------------------------------------!
  SUBROUTINE card_default( card )
    !
    !
    USE autopilot, ONLY : init_autopilot
    !
    USE read_namelists_module, ONLY : sm_not_set
    !
    !
    IMPLICIT NONE
    !
    !
    CHARACTER( len = * ),INTENT( IN ) :: card
    !
    !
    SELECT CASE ( trim(card) )
       !
    CASE ('INIT_AUTOPILOT')
       CALL init_autopilot()
       !
    CASE ('ATOMIC_LIST')
       !
       ! ... nothing to initialize
       ! ... because we don't have nat
       !
    CASE ('CHAIN' )
       !
       ! ... nothing to initialize
       ! ... because we don't have nat
       !
    CASE ('CELL')
       trd_ht = .false.
       rd_ht = 0.0_DP
       !
    CASE ('ATOMIC_SPECIES')
       atom_mass = 0.0_DP
       hubbard_u = 0.0_DP
       hubbard_j0 = 0.0_DP
       hubbard_alpha = 0.0_DP
       hubbard_beta = 0.0_DP
       starting_magnetization = sm_not_set
       starting_ns_eigenvalue = -1.0_DP
       angle1 = 0.0_DP
       angle2 = 0.0_DP
       ion_radius = 0.5_DP
       nhgrp = 0
       fnhscl = -1.0_DP
       tranp = .false.
       amprp = 0.0_DP
       !
    CASE ('K_POINTS')
       k_points = 'gamma'
       tk_inp   = .false.
       nkstot   = 1
       nk1      = 0
       nk2      = 0
       nk3      = 0
       k1       = 0
       k2       = 0
       k3       = 0
       !
    CASE ('OCCUPATIONS')
       tf_inp = .FALSE.
       !
    CASE ('CONSTRAINTS')
       nconstr_inp    = 0
       constr_tol_inp = 1.E-6_DP
       !
    CASE ('CLIMBING_IMAGES')
       ! ... nothing to initialize
       !
    CASE ('PLOT_WANNIER')
       !
       !       wannier_index =
       !
    CASE ('KSOUT')
       ! ... not yet implemented in xml reading
       CALL allocate_input_iprnks( 0, nspin )
       nprnks  = 0
       !
    CASE ('DIPOLE')
       ! ... not yet implemented in xml reading
       tdipole_card = .FALSE.
    CASE ('ESR')
       ! ... not yet implemented in xml reading
       iesr_inp = 1
       !
    CASE ('ION_VELOCITIES')
       ! ... not yet implemented in xml reading
       tavel = .false.
       !
    CASE DEFAULT
       CALL errore ( 'card_default', 'You want to initialize a card that does &
            &not exist or is not yet implemented ( '//trim(card)//' card)', 1 )
       !
    END SELECT
    !
    !
  END SUBROUTINE card_default
  !
  !
  !
  !
  !---------------------------------------------------------------------------!
  !    This subroutine broadcasts the varibles defined in the various cards;  !
  !    the input string is the name of the card that you want to broadcast    !
  !---------------------------------------------------------------------------!
  SUBROUTINE card_bcast( card )
    !
    !
    USE io_global, ONLY : ionode, ionode_id                                                           
    !
    USE mp,        ONLY : mp_bcast
    !
    IMPLICIT NONE
    !
    !
    CHARACTER( len = * ),INTENT( IN ) :: card
    INTEGER :: nspin0
    !
    !
    SELECT CASE ( trim(card) )
       !
       !
    CASE ( 'CELL' )
       CALL mp_bcast( ibrav, ionode_id )
       CALL mp_bcast( celldm, ionode_id )
       CALL mp_bcast( A, ionode_id )
       CALL mp_bcast( B, ionode_id )
       CALL mp_bcast( C, ionode_id )
       CALL mp_bcast( cosAB, ionode_id )
       CALL mp_bcast( cosAC, ionode_id )
       CALL mp_bcast( cosBC, ionode_id )
       CALL mp_bcast( cell_units, ionode_id )
       CALL mp_bcast( rd_ht, ionode_id )
       CALL mp_bcast( trd_ht, ionode_id )
       !
    CASE ( 'ATOMIC_SPECIES' )
       CALL mp_bcast( ntyp, ionode_id )
       CALL mp_bcast( atom_mass, ionode_id )
       CALL mp_bcast( atom_pfile, ionode_id )
       CALL mp_bcast( atom_label, ionode_id )
       CALL mp_bcast( taspc, ionode_id )
       CALL mp_bcast( hubbard_u, ionode_id )
       CALL mp_bcast( hubbard_j0, ionode_id )
       CALL mp_bcast( hubbard_alpha, ionode_id )
       CALL mp_bcast( hubbard_beta, ionode_id )
       CALL mp_bcast( starting_magnetization, ionode_id )
       CALL mp_bcast( starting_ns_eigenvalue, ionode_id )
       CALL mp_bcast( angle1, ionode_id )
       CALL mp_bcast( angle2, ionode_id )
       CALL mp_bcast( ion_radius, ionode_id )
       CALL mp_bcast( nhgrp, ionode_id )
       CALL mp_bcast( fnhscl, ionode_id )
       CALL mp_bcast( tranp, ionode_id )
       CALL mp_bcast( amprp, ionode_id )
       !
    CASE ( 'ATOMIC_LIST' )
       CALL mp_bcast( atomic_positions, ionode_id )
       CALL mp_bcast( nat, ionode_id )
!       CALL mp_bcast( num_of_images, ionode_id )
       ! ... ionode has already done it inside card_xml_atomic_list
       IF (.not.ionode) THEN
          CALL allocate_input_ions( ntyp, nat )
       END IF
!       CALL mp_bcast( pos, ionode_id )
       CALL mp_bcast( if_pos, ionode_id )
       CALL mp_bcast( na_inp, ionode_id )
       CALL mp_bcast( sp_pos, ionode_id )
       CALL mp_bcast( rd_pos, ionode_id )
       CALL mp_bcast( sp_vel, ionode_id )
       CALL mp_bcast( rd_vel, ionode_id )
       CALL mp_bcast( tapos, ionode_id )
       !
!    CASE ( 'CHAIN' )
!       CALL mp_bcast( atomic_positions, ionode_id )
!       CALL mp_bcast( nat, ionode_id )
!       CALL mp_bcast( num_of_images, ionode_id )
!       ! ... ionode has already done it inside card_xml_atomic_list
!       IF (.not.ionode) THEN
!          CALL allocate_input_ions( ntyp, nat )
!          IF (num_of_images>1) THEN
!             IF ( allocated( pos ) ) deallocate( pos )
!             allocate( pos( 3*nat,  num_of_images ) )
!          END IF
!       END IF
!       CALL mp_bcast( pos, ionode_id )
!       CALL mp_bcast( if_pos, ionode_id )
!       CALL mp_bcast( sp_pos, ionode_id )
!       CALL mp_bcast( rd_pos, ionode_id )
!       CALL mp_bcast( na_inp, ionode_id )
!       CALL mp_bcast( tapos, ionode_id )
       !
    CASE ( 'CONSTRAINTS' )
       CALL mp_bcast( nconstr_inp, ionode_id )
       CALL mp_bcast( constr_tol_inp, ionode_id )
       IF ( .not.ionode ) CALL allocate_input_constr()
       CALL mp_bcast( constr_type_inp, ionode_id )
       CALL mp_bcast( constr_target_inp, ionode_id )
       CALL mp_bcast( constr_target_set, ionode_id )
       CALL mp_bcast( constr_inp, ionode_id )
       !
    CASE ( 'K_POINTS' )
       CALL mp_bcast( k_points, ionode_id )
       CALL mp_bcast( nkstot, ionode_id )
       CALL mp_bcast( nk1, ionode_id )
       CALL mp_bcast( nk2, ionode_id )
       CALL mp_bcast( nk3, ionode_id )
       CALL mp_bcast( k1, ionode_id )
       CALL mp_bcast( k2, ionode_id )
       CALL mp_bcast( k3, ionode_id )
       CALL mp_bcast( xk, ionode_id )
       CALL mp_bcast( wk, ionode_id )
       !
    CASE ( 'OCCUPATIONS' )
       IF ( .not.ionode ) THEN
          nspin0 = nspin
          if ( nspin == 4 ) nspin0 = 1
          ALLOCATE( f_inp (nbnd, nspin0 ) )
       END IF
       CALL mp_bcast( f_inp, ionode_id )
       !
!    CASE ( 'CLIMBING_IMAGES' )
!       IF ( .not.ionode ) ALLOCATE( climbing( num_of_images ) )
!       CALL mp_bcast( climbing, ionode_id )
       !
    CASE ( 'PLOT_WANNIER' )
       CALL mp_bcast( wannier_index, ionode_id )
       !
    CASE DEFAULT
       CALL errore ( 'card_bcast', 'You want to broadcast a card that does &
            &not exist or is not yet implemented', 1 )
       !
       !
    END SELECT
    !
    !
    !
  END SUBROUTINE card_bcast
  !
  !
  !-------------------------------------------------------------------------!
  ! Here after there are the manuals and the reading of the xml cards       !
  ! For more information see the Help file                                  !
  !-------------------------------------------------------------------------!
  !                                                                         !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !                                                                         !
  !  CELL  (compulsory)                                                     !
  !                                                                         !
  !   specify the cell of your calculation                                  !
  !                                                                         !
  ! Syntax:                                                                 !
  !                                                                         !
  !   <cell type="type" sym="sym">                                          !
  !       depends on the type                                               !
  !   </cell>                                                               !
  !                                                                         !
  !  sym can be cubic or exagonal                                           !
  !                                                                         !
  !  if:                                                                    !
  !                                                                         !
  !  1) type is qecell, inside CELL node there is:                          !
  !                                                                         !
  !      <qecell ibrav="ibrav" alat="celldm(1)">                            !
  !         <real rank="1" n1="6">                                          !
  !            celldm(2) celldm(3) celldm(4) celldm(5) celldm(6)            !
  !         </real>                                                         !
  !      </qecell>                                                          !
  !                                                                         !
  !  2) type is abc, inside CELL node there is:                             !
  !                                                                         !
  !      <abc ibrav="ibrav">                                                !
  !          A B C cosAB cosAC cosBC                                        !
  !      </abc>                                                             !
  !                                                                         !
  !  3) type is matrix, inside there will be:                               !
  !                                                                         !
  !      <matrix units="units" alat="alat">                                   !
  !        <real rank="2" n1="3" n2="3">                                    !
  !          HT(1,1) HT(1,2) HT(1,3)                                        !
  !          HT(2,1) HT(2,2) HT(2,3)                                        !
  !          HT(3,1) HT(3,2) HT(3,3)                                        !
  !        </real>                                                          !
  !      </matrix>                                                          !
  !                                                                         !
  !                                                                         !
  !      Where:                                                             !
  !      HT(i,j) (real)  cell dimensions ( in a.u. ),                       !
  !                      note the relation with lattice vectors:            !
  !                      HT(1,:) = A1, HT(2,:) = A2, HT(3,:) = A3           !
  !      units            can be bohr (default) or alat (in this case you   !
  !                      have to specify alat)                              !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !
  SUBROUTINE card_xml_cell ( )
    !
    IMPLICIT NONE
    !
    !
    CHARACTER( LEN = iotk_attlenx ) :: attr, attr2
    CHARACTER( LEN = 20 ) :: option,option2
    INTEGER :: i, j, ierr
    LOGICAL :: found
    REAL( kind = DP ), DIMENSION(6) :: vect_tmp
    !
    !
    !
    CALL iotk_scan_begin( xmlinputunit, 'cell', attr = attr, found = found, ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'read_xml_cell', 'error scanning begin of cell &
         &card', ABS( ierr ) )
    !
    IF ( found ) THEN
       !
       CALL iotk_scan_attr( attr, 'type', option, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error scanning type &
            &attribute of cell node', abs(ierr) )
       !
       !
       IF ( trim(option) == 'qecell' ) THEN
          !
          CALL iotk_scan_begin( xmlinputunit, 'qecell', attr2, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error scanning begin &
               &of qecell node', abs(ierr) )
          !
          CALL iotk_scan_attr( attr2, 'ibrav', ibrav, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error reading ibrav &
               &attribute of qecell node', abs(ierr) )
          !
          CALL iotk_scan_attr(attr2, 'alat', celldm(1), ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error reading alat &
               &attribute of qecell node', abs(ierr) )
          !
          CALL iotk_scan_dat_inside( xmlinputunit, celldm(2:6), ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error reading data inside &
               &qecell node', abs(ierr) )
          !
          CALL iotk_scan_end( xmlinputunit, 'qecell', ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error scanning end of &
               &qecell node', abs(ierr) )
          !
       ELSE IF ( trim(option) == 'abc' ) THEN
          !
          CALL iotk_scan_begin(xmlinputunit, 'abc', attr2, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error scanning begin &
               &of abc node', abs(ierr) )
          !
          CALL iotk_scan_attr( attr2, 'ibrav', ibrav, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error reading ibrav &
               &attribute of abc node', abs(ierr) )
          !
          CALL iotk_scan_dat_inside( xmlinputunit, vect_tmp, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error reading data inside &
               &abc node', abs(ierr) )
          !
          A = vect_tmp(1) 
          B = vect_tmp(2)
          C = vect_tmp(3)
          cosAB = vect_tmp(4)
          cosAC = vect_tmp(5)
          cosBC = vect_tmp(6)
          !
          CALL iotk_scan_end(xmlinputunit,'abc', ierr = ierr)
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error scanning end of &
               &abc node', abs(ierr) )
          !
       ELSE IF (trim(option)=='matrix') THEN
          !
          ibrav = 0
          !
          CALL iotk_scan_begin( xmlinputunit, 'matrix', attr2, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error scanning begin &
               &of matrix node', abs(ierr) )
          !
          CALL iotk_scan_attr( attr2, 'units', option2, found = found, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error reading units attribute &
               &of matrix node', abs(ierr) )
          !
          IF (found) THEN
             IF ( trim(option2) == 'alat' ) THEN
                !
                cell_units = 'alat'
                !
                CALL iotk_scan_attr(attr2, 'alat', celldm(1), ierr = ierr )
                IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error reading alat&
                     &attribute of MATRIX node', abs(ierr) )
                !
             ELSE IF ( trim(option2) == 'bohr' ) THEN
                !
                cell_units = 'bohr'
                !
             ELSE
                !
                CALL errore( 'card_xml_cell', 'invalid units attribute', abs(ierr) )
                !
             END IF
          ELSE
             !
             cell_units = 'bohr'
             !
          END IF
          !
          !
          CALL iotk_scan_dat_inside( xmlinputunit, rd_ht, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error reading data inside &
               &matrix node', abs(ierr) )
          !
          rd_ht = transpose( rd_ht )
          trd_ht = .TRUE.
          !
          CALL iotk_scan_end( xmlinputunit, 'matrix', ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_cell', 'error scanning end of &
               &matrix node', abs(ierr) )
          !
       ELSE
          CALL errore( 'card_xml_cell', 'type '//trim(option)//' in cell node does not exist', 1 )
       END IF
       !
       CALL iotk_scan_end( xmlinputunit, 'cell', ierr = ierr)
       IF ( ierr /= 0 ) CALL errore( 'read_xml_pw', 'error scanning end of cell &
            &card', ABS( ierr ) )
    ELSE
       !
       CALL errore( 'read_xml_pw', 'cell card not found', 1 )
       !
    END IF
    !
    !
    RETURN
    !
  END SUBROUTINE card_xml_cell
  !
  !
  !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !                                                                         !
  ! ATOMIC_SPECIES  (compulsory)                                            !
  !                                                                         !
  !   set the atomic species been read and their pseudopotential file       !
  !                                                                         !
  ! Syntax:                                                                 !
  !                                                                         !
  !    <atomic_species ntyp="ntyp">                                         !
  !                                                                         !
  !       <specie name="label(i)">                                          !
  !                                                                         !
  !           <property name="mass">                                        !
  !              <real>                                                     !
  !                 mass(i)                                                 !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="pseudofile">                                  !
  !              <string>                                                   !
  !                 psfile(i)                                               !
  !              </string>                                                  !
  !           </property>                                                   !
  ![ optional                                                               !
  !           <property name="starting_magnetization">                      !
  !              <real>                                                     !
  !                 starting_magnetization(i)                               !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="hubbard_alpha">                               !
  !              <real>                                                     !
  !                 hubbard_alpha(i)                                        !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="hubbard_u">                                   !
  !              <real>                                                     !
  !                 hubbard_alpha(i)                                        !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="starting_ns_eigenvalue" ispin="" ns="">       !
  !              <real>                                                     !
  !                 starting_ns_eigenvalue(ns , ispin, i )                  !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="angle1">                                      !
  !              <real>                                                     !
  !                 angle1(i)                                               !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="angle2">                                      !
  !              <real>                                                     !
  !                 angle2(i)                                               !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="ion_radius">                                  !
  !              <real>                                                     !
  !                 ion_radius(i)                                           !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="nhgrp">                                       !
  !              <integer>                                                  !
  !                 nhgrp(i)                                                !
  !              </integer>                                                 !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="fnhscl">                                      !
  !              <real>                                                     !
  !                 fnhscl(i)                                               !
  !              </real>                                                    !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="tranp">                                       !
  !              <logical>                                                  !
  !                 tranp(i)                                                !
  !              </logical>                                                 !
  !           </property>                                                   !
  !                                                                         !
  !           <property name="amprp">                                       !
  !              <real>                                                     !
  !                 amprp(i)                                                !
  !              </real>                                                    !
  !           </property>                                                   !
  !]                                                                        !
  !       </specie>                                                         !
  !       ....                                                              !
  !       ....                                                              !
  !    </atomic_species>                                                    !
  !                                                                         !
  ! Where:                                                                  !
  !                                                                         !
  !      only the pseudofile property is compulsory, the others are optional!
  !                                                                         !
  !      label(i)  ( character(len=4) )  label of the atomic species        !
  !      mass(i)   ( real )              atomic mass                        !
  !                                      ( in u.m.a, carbon mass is 12.0 )  !
  !      psfile(i) ( character(len=80) ) file name of the pseudopotential   !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !
  SUBROUTINE card_xml_atomic_species( )
    !
    IMPLICIT NONE
    !
    !
    INTEGER            :: is, ip, ierr, direction
    CHARACTER( LEN = 4 )   :: lb_pos
    CHARACTER( LEN = 256 ) :: psfile
    CHARACTER( LEN = iotk_attlenx ) :: attr, attr2
    LOGICAL :: found, psfile_found
    !
    !
    !
    CALL iotk_scan_begin( xmlinputunit, 'atomic_species', attr = attr, found = found, ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'read_xml_pw', 'error scanning begin of atomic_species &
         &card', ABS( ierr ) )
    !
    IF ( found ) THEN
       !
       CALL iotk_scan_attr( attr, 'ntyp', ntyp, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_species',  'error &
            &reading ntyp attribute inside atomic_species node', abs( ierr ) )
       !
       IF( ntyp < 0 .OR. ntyp > nsx ) &
            CALL errore( 'card_xml_atomic_species', &
            ' ntyp is too large', MAX( ntyp, 1) )
       !
       DO is = 1, ntyp
          !
          CALL iotk_scan_begin( xmlinputunit, 'specie', attr = attr2, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_species',  'error &
               &scanning specie node', abs( ierr ) )
          !
          CALL iotk_scan_attr( attr2, 'name', lb_pos, ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_species',  'error &
               &reading name attribute of specie node', abs( ierr ) )
          !
          psfile_found = .false.
          !
          DO
             CALL iotk_scan_begin( xmlinputunit, 'property', attr = attr2, &
                  direction = direction, ierr = ierr )
             IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_species',  'error &
                  &scanning begin property node', abs( ierr ) )
             !
             IF (direction == -1) EXIT
             !
             CALL read_property( attr2 )
             !
             !
             CALL iotk_scan_end( xmlinputunit, 'property', ierr = ierr )
             IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_species',  'error &
                  &scanning end of property node', abs( ierr ) )

          END DO
          !
          CALL iotk_scan_end( xmlinputunit, 'property', ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_species',  'error &
               &scanning end of property node', abs( ierr ) )
          !
          CALL iotk_scan_end( xmlinputunit, 'specie', ierr = ierr )
          IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_species',  'error &
               &scanning end of specie node', abs( ierr ) )
          !
          IF  (.not. psfile_found ) CALL errore( 'card_xml_atomic_species', &
               'no pseudofile found', abs( is ) )
          !
          atom_pfile(is) = trim( psfile )
          lb_pos         = adjustl( lb_pos )
          atom_label(is) = trim( lb_pos )
          !

          !
          DO ip = 1, is - 1
             !
             IF ( atom_label(ip) == atom_label(is) ) THEN
                CALL errore( ' card_xml_atomic_species ',  &
                     ' two occurrences of the same atomic label',  is )
             ENDIF
          ENDDO
          !
       ENDDO
       !
       ! ... this variable is necessary to mantain compatibility.
       ! ... With new xml input the compulsory of atomic_species is already given
       !
       taspc = .true.
       !
       CALL iotk_scan_end( xmlinputunit, 'atomic_species', ierr = ierr )
       IF (ierr/=0)  CALL errore( 'card_xml_atomic_species', 'error scanning end of &
            &atomic_species node', ABS( ierr ) )
       !
    ELSE
       !
       CALL errore( 'read_xml_pw', 'atomic_species  card not found', 1 )
       !
    ENDIF
    !
    RETURN
    !
  CONTAINS
    !
    SUBROUTINE read_property ( attr_in)
      !
      IMPLICIT NONE
      !
      CHARACTER( len = * ), INTENT( in ) :: attr_in
      INTEGER :: index1, index2
      CHARACTER( len = 50 ) :: prop_name
      !
      CALL iotk_scan_attr( attr_in, 'name', prop_name, ierr = ierr )
      IF (ierr/=0)  CALL errore( 'card_xml_atomic_species', 'error reading name &
           &attribute of property node', ABS( is ) )

      SELECT CASE ( trim(prop_name) )
         !
      CASE ( 'mass' )
         CALL iotk_scan_dat_inside( xmlinputunit, atom_mass(is) , ierr = ierr)
         !
      CASE ( 'pseudofile' )
         CALL iotk_scan_dat_inside( xmlinputunit, psfile, ierr = ierr)
         psfile = clean_str( psfile )
         psfile_found = .true.
         !
      CASE ( 'starting_magnetization' )
         CALL iotk_scan_dat_inside( xmlinputunit, starting_magnetization( is ),&
              ierr = ierr)
         !
      CASE ( 'hubbard_alpha' )
         CALL iotk_scan_dat_inside( xmlinputunit, hubbard_alpha( is ),&
              ierr = ierr)
         !
      CASE ( 'hubbard_beta' )
         CALL iotk_scan_dat_inside( xmlinputunit, hubbard_beta( is ),&
              ierr = ierr)
         !
      CASE ( 'hubbard_u' )
         CALL iotk_scan_dat_inside( xmlinputunit, hubbard_u( is ),&
              ierr = ierr)
         !
      CASE ( 'hubbard_j0' )
         CALL iotk_scan_dat_inside( xmlinputunit, hubbard_j0( is ),&
              ierr = ierr)
         !
      CASE ( 'starting_ns_eigenvalue' )
         !
         CALL iotk_scan_attr( attr_in, 'ns', index1, ierr = ierr )
         IF (ierr/=0)  CALL errore( 'card_xml_atomic_species', 'error reading ns &
              &attribute of property node', ABS( is ) )
         !
         CALL iotk_scan_attr( attr_in, 'ispin', index2, ierr = ierr )
         IF (ierr/=0)  CALL errore( 'card_xml_atomic_species', 'error reading ispin &
              &attribute of property node', ABS( is ) )
         !
         CALL iotk_scan_dat_inside( xmlinputunit, &
              starting_ns_eigenvalue( index1, index2, is), ierr = ierr)
         !
      CASE ( 'angle1' )
         CALL iotk_scan_dat_inside( xmlinputunit, angle1( is ),&
              ierr = ierr)
         !
      CASE ( 'angle2' )
         !
         CALL iotk_scan_dat_inside( xmlinputunit, angle2( is ),&
              ierr = ierr)
         !
      CASE ( 'ion_radius' )
         !
         CALL iotk_scan_dat_inside( xmlinputunit, ion_radius( is ),&
              ierr = ierr)
         !
      CASE ( 'nhgrp' )
         !
         CALL iotk_scan_dat_inside( xmlinputunit, nhgrp( is ),&
              ierr = ierr)
         !
      CASE ( 'fnhscl' )
         !
         CALL iotk_scan_dat_inside( xmlinputunit, fnhscl( is ),&
              ierr = ierr)
         !
      CASE ( 'tranp' )
         !
         CALL iotk_scan_dat_inside( xmlinputunit, tranp( is ),&
              ierr = ierr)
         !
      CASE ( 'amprp' )
         !
         CALL iotk_scan_dat_inside( xmlinputunit, amprp( is ),&
              ierr = ierr)
         !
      CASE DEFAULT
         CALL errore( 'card_xml_atomic_species', 'property '&
              //trim(prop_name)//' not known', abs( is ) )
      END SELECT
      !
      !
      IF ( ierr /= 0 )  CALL errore( 'card_xml_atomic_species', 'error reading ' &
           //trim(prop_name)//' data', abs( is ) )
      !
    END SUBROUTINE read_property
    !
  END SUBROUTINE card_xml_atomic_species
  !
  !
  !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !                                                                         !
  !                                                                         !
  ! ATOMIC_LIST (compulsory for PW)                                         !
  !                                                                         !
  !   set the atomic positions                                              !
  !                                                                         !
  ! Syntax:                                                                 !
  !                                                                         !
  !  <atomic_list units="units_option" nat="natom">                         !
  !     <atom name="label(1)">                                              !
  !        <position ifx="mbl(1,1)" ify="mbl(2,1)" ifz="mbl(3,1)">          !
  !           <real rank="1" n1="3">                                        !
  !              tau(1,1)  tau(2,1)  tau(3,1)                               !
  !           </real>                                                       !
  !        </position>                                                      !
  !     </atom>                                                             !
  !     ...                                                                 !
  !  </atomic_list>                                                         !
  !                                                                         !
  ! Where:                                                                  !
  !                                                                         !
  !   units_option == crystal   position are given in scaled units          !
  !   units_option == bohr      position are given in Bohr                  !
  !   units_option == angstrom  position are given in Angstrom              !
  !   units_option == alat      position are given in units of alat         !
  !                                                                         !
  !   label(k) ( character(len=4) )  atomic type                            !
  !   tau(:,k) ( real )              coordinates  of the k-th atom          !
  !   mbl(:,k) ( integer )           mbl(i,k) > 0 the i-th coord. of the    !
  !                                  k-th atom is allowed to be moved       !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !
  SUBROUTINE card_xml_atomic_list( )
    !
    IMPLICIT NONE
    !
    !
    CHARACTER( len = iotk_attlenx ) :: attr
    INTEGER :: ierr, is
    LOGICAL :: found
    !
    !
    CALL iotk_scan_begin( xmlinputunit, 'atomic_list', attr, ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_list', 'error scanning begin &
         &of atomic_list node', abs(ierr) )
    !
    CALL iotk_scan_attr( attr, 'units', atomic_positions, found = found, ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_list', 'error reading units &
         &attribute of atomic_list node', abs(ierr) )
    !
    IF ( found ) THEN
       IF ( (trim( atomic_positions ) == 'crystal') .or. &
            (trim( atomic_positions ) == 'bohr') .or. &
            (trim( atomic_positions ) == 'angstrom').or. &
            (trim( atomic_positions ) == 'alat') ) THEN
          atomic_positions = trim( atomic_positions )
       ELSE
          CALL errore( 'car_xml_atom_lists',  &
               'error in units attribute of atomic_list node, unknow '&
               & //trim(atomic_positions)//' units', 1 )
       ENDIF
    ELSE
       ! ... default value
       atomic_positions = 'alat'
    ENDIF
    !
    CALL iotk_scan_attr( attr, 'nat', nat, ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_list', 'error reading nat attribute &
         &of atomic_list node', abs(ierr) )
    !
    IF ( nat < 1 ) THEN
       CALL errore( 'card_xml_atomic_list',  'nat out of range',  nat )
    END IF
    !
    ! ... allocation of needed arrays
    CALL allocate_input_ions( ntyp, nat )
    !
    if_pos = 1
    sp_pos = 0
    rd_pos = 0.0_DP
    sp_vel = 0
    rd_vel = 0.0_DP
    na_inp = 0
    !
    !
    CALL read_image( 1, rd_pos, rd_vel )
    !
    CALL iotk_scan_end( xmlinputunit, 'atomic_list', ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'card_xml_atomic_list', 'error scanning end of &
         &atomic_list node', abs( ierr ) )
    !
    !
    tapos = .true.
    !
    RETURN
    !
    !
  END SUBROUTINE card_xml_atomic_list
  !
  !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-!
  !                                                                            !
  !                                                                            !
  ! CHAIN  (used in neb and smd calculation)                                   !
  !                                                                            !
  !   set the atomic positions for a chian                                     !
  !                                                                            !
  ! Syntax:                                                                    !
  !                                                                            !
  !  <chain num_of_images="">                                                  !
  !     <atomic_list units="units_option" nat="natom" num="1">                 !
  !        <atom name="label(1)" ifx="mbl(1,1)" ify="mbl(2,1)" ifz="mbl(3,1)"> !
  !          <position>                                                        !
  !             <real rank="1" n1="3">                                         !
  !                 tau(1,1)  tau(2,1)  tau(3,1)                               !
  !             </real>                                                        !
  !          </position>
  !        </atom>                                                             !
  !        ...                                                                 !
  !     </atomic_list>                                                         !
  !     <atomic_list num="2">                                                  !
  !        ...                                                                 !
  !     </atomic_list>                                                         !
  !     ...                                                                    !
  !  </chain>                                                                  !
  !                                                                            !
  !                                                                            !
  ! Where:                                                                     !
  !                                                                            !
  ! notation of atomic_list node is the same of the atomic_list cards.         !
  ! the difference is that inside the chain card you put more atomic_list node !
  ! with the attribute num that indicates the number of the image              !
  !                                                                            !
  !                                                                            !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-!
  !
  SUBROUTINE card_xml_chain( )
    !
    IMPLICIT NONE
    !
    !
    CHARACTER( LEN = iotk_attlenx ) :: attr
    LOGICAL :: found,end_of_chain
    INTEGER :: ierr
    REAL (DP), DIMENSION( :, :), ALLOCATABLE :: tmp_image
    !
    !
    end_of_chain = .false.

!    CALL iotk_scan_begin( xmlinputunit, 'chain', attr, ierr = ierr )
!    IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error scanning begin &
!         &of chain node', abs(ierr) )
!    !
!    !
!    CALL iotk_scan_attr( attr, 'num_of_images', num_of_images, ierr = ierr )
!    IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error reading &
!         &num_of_images attribute of chain node', abs(ierr) )
!    !
!    IF ( num_of_images < 1 )  CALL errore ( 'card_xml_chain', 'null &
!         &or negative num_of_images', 1 )
!    !
!    CALL find_image( 1 )
!    IF (end_of_chain) CALL errore( 'card_xml_chain', 'first image not found', 1 )
!    !
!    CALL iotk_scan_attr( attr, 'units', atomic_positions, found = found, ierr = ierr )
!    IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error reading units attribute &
!         &of atomic_list node', abs(ierr) )
!    !
!    IF ( found ) THEN
!       IF ( (trim( atomic_positions ) == 'crystal') .or. &
!            (trim( atomic_positions ) == 'bohr') .or. &
!            (trim( atomic_positions ) == 'angstrom').or. &
!            (trim( atomic_positions ) == 'alat') ) THEN
!          atomic_positions = trim( atomic_positions )
!       ELSE
!          CALL errore( 'car_xml_chain',  &
!               'error in units attribute of atomic_list node, unknow '&
!               & //trim(atomic_positions)//' units', 1 )
!       ENDIF
!    ELSE
!       ! ... default value
!       atomic_positions = 'alat'
!    ENDIF
!    !
!    CALL iotk_scan_attr( attr, 'nat', nat, ierr = ierr )
!    IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error reading nat attribute &
!         &of atomic_list node', abs(ierr) )
!    !
!    IF ( nat < 1 ) THEN
!       CALL errore( 'card_xml_chain',  'nat out of range',  abs(nat) )
!    END IF
!    
!    ! ... allocation of needed arrays
!    CALL allocate_input_ions( ntyp, nat )
!    !
!    if_pos = 1
!    sp_pos = 0
!    rd_pos = 0.0_DP
!    na_inp = 0
!    !
!    !
!    IF ( allocated( pos ) ) deallocate( pos )
!    allocate( pos( 3*nat,  num_of_images ) )
    !
!    allocate( tmp_image( 3, nat ) )
    !
!    pos(:, :) = 0.0_DP
    !
!    CALL read_image( 1, tmp_image )
!    ! ...  transfer of tmp_image data in pos array (to mantain compatibility)
!    CALL reshaffle_indexes( 1 )
    !
!    input_images = 1
    !
!    DO
!       !
!       ! ... a trick to move the cursor at the beginning of chain node
!       !
!       CALL iotk_scan_end( xmlinputunit, 'atomic_list', ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error scanning end of &
!            &atomic_list node', input_images )
!       !
!       CALL iotk_scan_end( xmlinputunit, 'chain', ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error scanning end of chain &
!            &node', abs(ierr) )
!       !
!       CALL iotk_scan_begin( xmlinputunit, 'chain', ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error scanning begin &
!            &of chain node', abs( ierr ) )
!       ! ... end of the trick
!       !
!       CALL find_image( input_images + 1 )
!       !
!       IF (end_of_chain) EXIT
!       !
!       input_images = input_images + 1
!       !
!       IF ( input_images > num_of_images ) CALL errore( 'card_xml_chain',&
!            'too many images in chain node', 1 )
!       !           
!       CALL read_image( input_images, tmp_image )
!       ! ... transfer tmp_image data in pos array (to mantain compatibility)
!       CALL reshaffle_indexes( input_images )
!       !
!    ENDDO
!    !
!    CALL iotk_scan_end( xmlinputunit, 'atomic_list', ierr = ierr )
!    IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error scanning end of &
!         &atomic_list node', abs(ierr) )
!    !
!    !
!    tapos = .true.
    !
!    DEALLOCATE(tmp_image)
    RETURN
    !
!  CONTAINS
    !
    ! ... does a scan to find the image with attribute num="iimage"
!    SUBROUTINE find_image( iimage )
!      !
!      INTEGER, INTENT( in ) :: iimage
!      INTEGER :: direction, rii
!      !
!      DO
!         CALL  iotk_scan_begin( xmlinputunit, 'atomic_list', attr, &
!              direction = direction, ierr = ierr )
!         IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error scanning begin &
!              &of atomic_list node', abs(ierr) )
!         !
!         CALL iotk_scan_attr( attr, 'num', rii, ierr = ierr )
!         IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error reading num &
!              &attribute of atomic_list node', abs(ierr) )
!         !
!         IF ( rii == iimage ) EXIT
!         !
!         IF ( direction == -1 ) THEN
!            end_of_chain = .true.
!            EXIT
!         END IF
!         !
!         CALL  iotk_scan_end( xmlinputunit, 'atomic_list', ierr = ierr )
!         IF ( ierr /= 0 ) CALL errore( 'card_xml_chain', 'error scanning end &
!              &of atomic_list node', abs(iimage) )
!         !
!      END DO
!      !
!    END SUBROUTINE find_image
!    !
!    ! ... copy the data from tmp_image to pos, necessary to mantain the notation
!    ! ... of old input
!    SUBROUTINE reshaffle_indexes( iimage )
!      !
!      INTEGER, INTENT( in ) :: iimage
!      INTEGER :: ia_tmp, idx_tmp
!      
!      DO ia_tmp = 1,nat
!         idx_tmp = 3*(ia_tmp -1 )
!         pos(idx_tmp+1:idx_tmp+3, iimage) = tmp_image( 1:3, ia_tmp )
!      END DO
!    END SUBROUTINE reshaffle_indexes
!    !
  END SUBROUTINE card_xml_chain
  !
  !
  !
!  ! ... Subroutine that reads a single image inside chain node
!  !
  SUBROUTINE read_image( image, image_pos, image_vel )
    !
    IMPLICIT NONE
    !
    INTEGER, INTENT( in ) :: image
    REAL( DP ), INTENT( inout ), DIMENSION( 3, nat ) :: image_pos
    REAL( DP ), INTENT( inout ), DIMENSION( 3, nat ), OPTIONAL :: image_vel
    !
    !
    INTEGER :: ia, idx, ierr, is, direction
    CHARACTER( len = iotk_attlenx ) :: attr
    CHARACTER( len = 4 ) :: lb_pos
    LOGICAL :: found_vel, read_vel
    REAL( DP ) :: default
    !
    default = 1.0_DP
    !
    ia = 0
    !
    read_vel = .true.
    IF (present(image_vel)) read_vel = .true.
    !
    DO
       !
       CALL iotk_scan_begin( xmlinputunit, 'atom', attr = attr, &
            direction = direction, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'read_image', 'error scanning begin of &
            &atom node', abs(ierr) )
       !
       IF (direction == -1) THEN
          IF (ia < nat) CALL errore( 'read_image', &
               'less atoms than axpected in atomic_list', image )
          EXIT
       END IF
       !
       ia = ia + 1
       !
       IF ( ia > nat) CALL errore( 'read_image', &
            'more atoms than axpected in atomic_list', image )
       !
       ! ... compulsory name attribute
       CALL iotk_scan_attr( attr, 'name', lb_pos, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'read_image', 'error reading &
            &name attribute of atom node', abs(ierr) )
       !
       CALL iotk_scan_dat( xmlinputunit,'position', image_pos( 1:3, ia ), attr = attr, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'read_image', 'error reading position data of &
            &atom node', abs(ierr) )
       !
       IF (read_vel) THEN
          CALL iotk_scan_begin( xmlinputunit, 'velocity', &
               found = found_vel, ierr = ierr)
          IF ( ierr /= 0 ) CALL errore( 'read_al_image', 'error scanning begin of &
               &velocity node', abs(ierr) )
          !
          IF (found_vel) THEN
             !
             CALL iotk_scan_dat_inside( xmlinputunit, image_vel( 1:3, ia ), ierr = ierr )
             IF ( ierr /= 0 ) CALL errore( 'read_al_image', 'error reading &
                  &velocity', abs(ierr) )
             !
             CALL iotk_scan_end( xmlinputunit, 'velocity', ierr = ierr)
             IF ( ierr /= 0 ) CALL errore( 'read_al_image', 'error scanning end of &
                  &velocity node', abs(ierr) )
             !
          ENDIF
       ENDIF
       !

       CALL iotk_scan_end( xmlinputunit, 'atom', ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'read_image', 'error scanning end of &
            &atom node', abs(ierr) )
       !
       !
       IF ( image  == 1 ) THEN
          !
          CALL iotk_scan_attr( attr, 'ifx', if_pos(1,ia), default = 1, ierr=ierr )
          IF ( ierr /= 0) CALL errore( 'read_image', &
               'error reading ifx attribute of atom node', image )
          !
          CALL iotk_scan_attr( attr, 'ify', if_pos(2,ia), default = 1, ierr = ierr )
          IF ( ierr /= 0) CALL errore( 'read_image', &
               'error reading ify attribute of atom node', image )
          !
          CALL iotk_scan_attr( attr, 'ifz', if_pos(3,ia), default = 1, ierr = ierr )
          IF ( ierr /= 0) CALL errore( 'read_image', &
               'error reading ifz attribute of atom node', image )
          !
          lb_pos = adjustl( lb_pos )
          !
          match_label_path: DO is = 1, ntyp
             !
             IF ( trim( lb_pos ) == trim( atom_label(is) ) ) THEN
                !
                sp_pos( ia ) = is
                IF (found_vel .and. read_vel) sp_vel( ia) = is 
                !
                EXIT match_label_path
                !
             ENDIF
             !
          ENDDO match_label_path
          !
          IF ( ( sp_pos( ia ) < 1 ) .or. ( sp_pos( ia ) > ntyp ) ) CALL errore( &
               'read_image', 'wrong name in atomic_list node', ia )
          !
          is = sp_pos( ia )
          !
          na_inp( is ) = na_inp( is ) + 1
          !
       ENDIF
       !
    ENDDO
    !
    CALL iotk_scan_end( xmlinputunit, 'atom', ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'read_image', 'error scanning end of &
         &atom node', abs(ierr) )
    !
    IF ( image == 1) THEN
       DO is = 1, ntyp
          IF( na_inp( is ) < 1 ) &
               CALL errore( 'read_image', 'no atom found in atomic_list for '&
               //trim(atom_label(is))//' specie', is )
       ENDDO
    ENDIF
   !
    RETURN
    !
  END SUBROUTINE read_image
  !
  !
  !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !                                                                         !
  !   K_POINTS                                                              !
  !                                                                         !
  !   use the specified set of k points                                     !
  !                                                                         !
  ! Syntax:                                                                 !
  !                                                                         !
  ! <k_points type="mesh_option">                                           !
  !                                                                         !
  ! if mesh_option = tpiba, crystal, tpiba_b or crystal_b :                 !
  !      <mesh npoints="n">                                                 !
  !         <real rank="2" n1="4" n2="n">                                   !
  !                                                                         !
  !            xk(1,1) xk(2,1) xk(3,1) wk(1)                                !
  !            ...     ...     ...     ...                                  !
  !            xk(1,n) xk(2,n) xk(3,n) wk(n)                                !
  !         </real>                                                         !
  !      </mesh>                                                            !
  !                                                                         !
  ! else if mesh_option = automatic                                         !
  !      <mesh>                                                             !
  !         <real rank="1" n1="6">                                          !
  !             nk1 nk2 nk3 k1 k2 k3                                        !
  !         </real>                                                         !
  !      </mesh>                                                            !
  !                                                                         !
  ! </k_points>                                                             !
  !                                                                         !
  !                                                                         !
  ! Where:                                                                  !
  !                                                                         !
  !   mesh_option == automatic  k points mesh is generated automatically    !
  !                             with Monkhorst-Pack algorithm               !
  !   mesh_option == crystal    k points mesh is given in stdin in scaled   !
  !                             units                                       !
  !   mesh_option == tpiba      k points mesh is given in stdin in units    !
  !                             of ( 2 PI / alat )                          !
  !   mesh_option == gamma      only gamma point is used ( default in       !
  !                             CPMD simulation )                           !
  !   mesh_option == tpiba_b    as tpiba but the weights gives the          !
  !                             number of points between this point         !
  !                             and the next                                !
  !   mesh_option == crystal_b  as crystal but the weights gives the        !
  !                             number of points between this point and     !
  !                             the next                                    !
  !                                                                         !
  !   n       ( integer )  number of k points                               !
  !   xk(:,i) ( real )     coordinates of i-th k point                      !
  !   wk(i)   ( real )     weights of i-th k point                          !
  !                                                                         !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !
  SUBROUTINE card_xml_kpoints( attr )
    !
    IMPLICIT NONE
    !
    CHARACTER( len = * ), INTENT( in ) :: attr
    !
    LOGICAL :: kband = .FALSE.
    CHARACTER( len = 20 ) :: type
    CHARACTER( len = iotk_attlenx ) :: attr2
    INTEGER :: i,j, nkaux, ierr
    INTEGER, DIMENSION( 6 ) :: tmp
    INTEGER, DIMENSION( : ), ALLOCATABLE :: wkaux
    REAL( DP ), DIMENSION( : , : ), ALLOCATABLE :: points_tmp, xkaux
    REAL( DP ) :: delta
    !
    !
    CALL iotk_scan_attr(attr, 'type', type, ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'card_xml_kpoints', 'error reading type attribute &
         &of k_points node', abs( ierr ) )
    !
    SELECT CASE ( trim( type ) )
       !
    CASE ('automatic')
       !automatic generation of k-points
       k_points = 'automatic'
       !
    CASE ('crystal')
       !  input k-points are in crystal (reciprocal lattice) axis
       k_points = 'crystal'
       !
    CASE ('crystal_b')
       k_points = 'crystal'
       kband=.true.
       !
    CASE ('tpiba')
       !  input k-points are in 2pi/a units
       k_points = 'tpiba'
       !
    CASE ('tpiba_b')
       k_points = 'tpiba'
       kband=.true.
       !
    CASE ('gamma')
       !  Only Gamma (k=0) is used
       k_points = 'gamma'
       !
    CASE DEFAULT
       !  by default, input k-points are in 2pi/a units
       k_points = 'tpiba'
       !
    END SELECT
    !
    IF ( k_points == 'automatic' ) THEN
       !
       ! ... automatic generation of k-points
       !
       nkstot = 0
       CALL iotk_scan_dat( xmlinputunit, 'mesh', tmp, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_kpoints', 'error reading data inside mesh &
            &node', abs( ierr ) )
       !
       nk1 = tmp( 1 )
       nk2 = tmp( 2 )
       nk3 = tmp( 3 )
       k1  = tmp( 4 )
       k2  = tmp( 5 )
       k3  = tmp( 6 )
       !
       ! ... some checks
       !
       IF ( k1 < 0 .or. k1 > 1 .or. &
               k2 < 0 .or. k2 > 1 .or. &
               k3 < 0 .or. k3 > 1 ) CALL errore &
               ('card_xml_kpoints', 'invalid offsets: must be 0 or 1', 1)
       !
       IF ( nk1 <= 0 .or. nk2 <= 0 .or. nk3 <= 0 ) CALL errore &
            ('card_xml_kpoints', 'invalid values for nk1, nk2, nk3', 1)
       !
    ELSE IF ( ( k_points == 'tpiba' ) .OR. ( k_points == 'crystal' ) ) THEN
       !
       ! ... input k-points are in 2pi/a units
       !
       CALL iotk_scan_begin( xmlinputunit, 'mesh', attr2, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_kpoints', 'error scanning begin of mesh &
            &node', abs( ierr ) )
       !
       CALL iotk_scan_attr( attr2, 'npoints', nkstot, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_kpoints', 'error reading attribute npoints of mesh &
            &node', abs( ierr ) )
       !
       !
       IF ( nkstot > size( xk, 2 )  ) CALL errore &
            ('card_xml_kpoints', 'too many k-points', nkstot)
       !
       allocate( points_tmp(4,nkstot) )
       !
       CALL iotk_scan_dat_inside( xmlinputunit, points_tmp, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_kpoints', 'error reading data inside mesh &
            &node', abs( ierr ) )
       !
       xk( :, 1:nkstot ) = points_tmp( 1:3, : )
       wk( 1:nkstot ) = points_tmp( 4, : )
       !
       deallocate( points_tmp )
       !
       CALL iotk_scan_end( xmlinputunit, 'mesh', ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_kpoints', 'error scanning end of mesh &
            &node', abs( ierr ) )
       !
       !
       IF ( kband ) THEN
          !
          nkaux=nkstot
          !
          allocate( xkaux( 3, nkstot ) )
          allocate( wkaux( nkstot ) )
          !
          xkaux( :, 1:nkstot ) = xk( :, 1:nkstot )
          wkaux( 1:nkstot ) = nint( wk(1:nkstot) )
          nkstot = 0
          !
          DO i = 1, nkaux-1
             !
             delta = 1.0_DP/wkaux(i)
             !
             DO j=0, wkaux(i)-1
                !
                nkstot=nkstot+1
                IF ( nkstot > SIZE (xk,2)  ) CALL errore &
                     ('card_xml_kpoints', 'too many k-points',nkstot)
                !
                xk( :, nkstot ) = xkaux( :, i ) + delta*j*( xkaux(:,i+1) - xkaux(:,i) ) 
                wk(nkstot)=1.0_DP
                !
             ENDDO
             !
          ENDDO
          !
          nkstot = nkstot + 1
          xk( :, nkstot ) = xkaux( :, nkaux )
          wk( nkstot ) = 1.0_DP
          !
          deallocate(xkaux)
          deallocate(wkaux)
       ENDIF
       !
    ELSE IF ( k_points == 'gamma' ) THEN
       !
       nkstot = 1
       xk(:, 1) = 0.0_DP
       wk(1) = 1.0_DP
       !
    ENDIF
    !
    tk_inp = .TRUE.
    !
    RETURN
    !
    !
  END SUBROUTINE card_xml_kpoints
  !
  !
  !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !                                                                         !
  ! OCCUPATIONS (optional)                                                  !
  !                                                                         !
  !   use the specified occupation numbers for electronic states.           !
  !                                                                         !
  ! Syntax (nspin == 1) or (nspin == 4):                                    !
  !                                                                         !
  !   <occupations>                                                         !
  !      <real rank="1" n1="nbnd">                                          !
  !         f(1)                                                            !
  !         ....                                                            !
  !         ....                                                            !
  !         f(nbnd)                                                         !
  !      </real>                                                            !
  !   </occupations>                                                        !
  !                                                                         !
  ! Syntax (nspin == 2):                                                    !
  !                                                                         !
  !   <occupations>                                                         !
  !         <real rank="2" n1="nbnd" n2="2">                                !
  !            u(1) ... u(nbnd)                                             !
  !            d(1) ... d(nbnd)                                             !
  !         </real>                                                         !
  !   </occupations>                                                        !
  !                                                                         !
  ! Where:                                                                  !
  !                                                                         !
  !      f(:) (real)  these are the occupation numbers                      !
  !                   for LDA electronic states.                            !
  !                                                                         !
  !      u(:) (real)  these are the occupation numbers                      !
  !                   for LSD spin == 1 electronic states                   !
  !      d(:) (real)  these are the occupation numbers                      !
  !                   for LSD spin == 2 electronic states                   !
  !                                                                         !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !
  SUBROUTINE card_xml_occupations( )
    !
    !
    IMPLICIT NONE
    ! 
    INTEGER :: nspin0, ierr
    REAL( DP ), ALLOCATABLE :: tmp_data(:)
    !
    !
    nspin0 = nspin
    IF (nspin == 4) nspin0 = 1
    !
    IF (nbnd==0) CALL errore( 'card_xml_occupation', 'nbdn is not defined ', 1 )
    !
    allocate ( f_inp ( nbnd, nspin0 ) )
    !
    IF ( nspin0 == 2 ) THEN
       !
       CALL iotk_scan_dat_inside( xmlinputunit, f_inp, ierr = ierr )
       !
       IF ( ierr /= 0 ) CALL errore( 'card_xml_occupations', 'error reading data inside &
            &occupations node', abs( ierr ) )
       !
    ELSE IF ( nspin0 == 1 ) THEN
       !
       ALLOCATE( tmp_data( nbnd ) )
       !
       CALL iotk_scan_dat_inside(xmlinputunit, tmp_data, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_occupations', 'error reading data inside &
            &occupations node', abs( ierr ) )
       !
       f_inp(:,1) = tmp_data
       !
       DEALLOCATE( tmp_data )
       !
    END IF
    !
    RETURN
    !
    !
  END SUBROUTINE card_xml_occupations
  !
  !
  !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !                                                                         !
  ! CONSTRAINTS (optional)                                                  !
  !                                                                         !
  !   Ionic Constraints                                                     !
  !                                                                         !
  ! Syntax:                                                                 !
  !                                                                         !
  !  <constraints n="nconstr" tol="constr_tol">                             !
  !                                                                         !
  !    <constraint type="constr_type(1)" target="CONSTR_TARGET(1)">         !
  !        <real rank="1" n1="4">                                           !
  !          constr(1,1) constr(2,1) constr(3,1) constr(4,1)                !
  !        </real>                                                          !
  !    </constraint>                                                        !
  !                                                                         !
  !    ...                                                                  !
  !    ...                                                                  !
  !                                                                         !
  !  </constraints>                                                         !
  !                                                                         !
  !                                                                         !
  !                                                                         !
  ! Where:                                                                  !
  !                                                                         !
  !      nconstr(INTEGER)    number of constraints                          !
  !                                                                         !
  !      constr_tol          tolerance for keeping the constraints          !
  !                          satisfied                                      !
  !                                                                         !
  !      constr_type(.)      type of constrain:                             !
  !                          1: for fixed distances ( two atom indexes must !
  !                             be specified )                              !
  !                          2: for fixed planar angles ( three atom indexes!
  !                             must be specified )                         !
  !                                                                         !
  !      constr_target(.)    target for the constrain ( in the case of      !
  !                          planar angles it is the COS of the angle ).    !
  !                          this variable is optional.                     !
  !                                                                         !
  !                                                                         !
  !      constr(1,.) constr(2,.) ...                                        !
  !                                                                         !
  !                          indices object of the constraint               !
  !                                                                         !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !
  SUBROUTINE card_xml_constraints( )
    !
    !
    IMPLICIT NONE
    ! 
    !
    LOGICAL :: found
    CHARACTER( len = iotk_attlenx ) :: attr2,attr
    INTEGER :: i, ierr, direction
    !
    !
    nconstr_inp = 0
    !
    DO
       !
       CALL iotk_scan_begin( xmlinputunit, 'constraint', direction = direction, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_constraints', &
            'error scanning begin of constraint node', nconstr_inp )
       !
       CALL iotk_scan_end( xmlinputunit, 'constraint', ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_constraints', &
            'error scanning end of constraint node', nconstr_inp )
       !
       IF (direction == -1) EXIT
       !
       nconstr_inp = nconstr_inp + 1
       !
    ENDDO


    CALL iotk_scan_end( xmlinputunit, 'constraints', ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'card_xml_constraints', &
         'error scanning end of constraints node', abs(ierr) )

    ! ... already did, it can not gives error
    CALL iotk_scan_begin( xmlinputunit, 'constraints', attr )
    !
    CALL iotk_scan_attr( attr, 'tol', constr_tol_inp, ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'card_xml_constraints', &
         'error reading tol attribute of constraints node', abs( ierr ) )
    !
    !
    WRITE( stdout, '(5x,a,i4,a,f12.6)' ) &
         'Reading',nconstr_inp,' constraints; tolerance:', constr_tol_inp
    !
    CALL allocate_input_constr()
    !
    DO i = 1, nconstr_inp
       !
       CALL iotk_scan_begin( xmlinputunit, 'constraint', attr2, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_constraints', &
            'error scanning begin of constraint node', abs( ierr ) )
       !
       CALL iotk_scan_attr( attr2, 'type', constr_type_inp(i), ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_constraints', &
            'error reading type attribute of constraint node', abs( ierr ) )
       !
       CALL iotk_scan_attr( attr2, 'target', constr_target_inp(i), found = found, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_constraints', &
            'error reading target attribute of constraint node', abs( ierr ) )
       !
       IF ( found ) constr_target_set(i) = .TRUE.
       !
       SELECT CASE( constr_type_inp(i) )
          !
       CASE( 'type_coord', 'atom_coord' )
          !
          CALL iotk_scan_dat_inside( xmlinputunit, constr_inp(:,i), ierr = ierr )
          IF ( ierr /= 0 ) GO TO 10
          !
          IF ( .not.constr_target_set(i) ) THEN
             !
             WRITE( stdout, '(7x,i3,a,i3,a,i2,a,2f12.6)' ) &
                  i,') '//constr_type_inp(i)(1:4),int( constr_inp(1,i) ),&
                  ' coordination wrt type:', int( constr_inp(2,i) ), &
                  ' cutoff distance and smoothing:',  constr_inp(3:4,i)
             !
          ELSE
             !
             WRITE( stdout, '(7x,i3,a,i3,a,i2,a,2f12.6,a,f12.6)') &
                     i,') '//constr_type_inp(i)(1:4),int( constr_inp(1,i) ),&
                     ' coordination wrt type:', int( constr_inp(2,i) ), &
                     ' cutoff distance and smoothing:',  constr_inp(3:4,i), &
                     '; target:', constr_target_inp(i)
             !
          END IF
          !
       CASE( 'distance' )
          !
          CALL iotk_scan_dat_inside( xmlinputunit, constr_inp(:,i), ierr = ierr )
          IF ( ierr /= 0 ) GO TO 10
          !
          IF ( .not.constr_target_set(i) ) THEN
             !
             WRITE( stdout, '(7x,i3,a,i3,a,i3)' ) &
                     i,') distance from atom:', int( constr_inp(1,i) ), &
                     ' to:', int( constr_inp(2,i) )
             !
          ELSE
             !
             WRITE( stdout, '(7x,i3,a,i3,a,i3,a,f12.6)' ) &
                     i,') distance from atom', int( constr_inp(1,i) ), &
                     ' to atom', int( constr_inp(2,i) ), &
                     '; target:', constr_target_inp(i)
             !
          ENDIF
          !
       CASE( 'planar_angle' )
          !
          CALL iotk_scan_dat_inside( xmlinputunit, constr_inp(:,i), ierr = ierr )
          IF ( ierr /= 0 ) GO TO 10
          !
          IF ( .not.constr_target_set(i) ) THEN
             !
             WRITE( stdout, '(7x,i3,a,3i3)') &
                     i,') planar angle between atoms: ', int( constr_inp(1:3,i) ) 
             !
          ELSE
             !
             WRITE(stdout, '(7x,i3,a,3i3,a,f12.6)') &
                  i,') planar angle between atoms: ', int( constr_inp(1:3,i) ),&
                  '; target:', constr_target_inp(i) 
             !
          ENDIF
          !
       CASE( 'torsional_angle' )
          !
          CALL iotk_scan_dat_inside( xmlinputunit, constr_inp(:,i), ierr = ierr )
          IF ( ierr /= 0 ) GO TO 10
          !
          IF ( .not.constr_target_set(i) ) THEN
             !
             WRITE( stdout, '(7x,i3,a,4i3)' ) &
                  i,') torsional angle between atoms: ', int( constr_inp(1:4,i) )
             !
          ELSE
             !
             WRITE( stdout, '(7x,i3,a,4i3,a,f12.6)' ) &
                  i,') torsional angle between atoms: ', int( constr_inp(1:4,i) ), &
                  '; target:', constr_target_inp(i)
             !
          ENDIF
          !
       CASE( 'bennett_proj' )
          !
          CALL iotk_scan_dat_inside( xmlinputunit, constr_inp(:,i), ierr = ierr )
          IF ( ierr /= 0 ) GO TO 10
          !
          IF (.not.constr_target_set(i)) THEN
             !
             WRITE( stdout, '(7x,i3,a,i3,a,3f12.6)' ) &
                  i,') bennet projection of atom ', int( constr_inp(1,i) ),&
                  ' along vector:', constr_inp(2:4,i)
             !
          ELSE
             !
             WRITE(stdout, '(7x,i3,a,i3,a,3f12.6,a,f12.6)') &
                  i,') bennet projection of atom ', int( constr_inp(1,i) ),&
                  ' along vector:', constr_inp(2:4,i), &
                  '; target:', constr_target_inp(i)
          ENDIF
          !
       CASE DEFAULT
          !
          CALL errore( 'card_xml_constraints', 'unknown constraint ' // &
                        & 'type: ' // trim( constr_type_inp(i) ), 1 )
          !
       END SELECT
       !
       CALL iotk_scan_end( xmlinputunit, 'constraint', ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_constraints', &
            'error scanning end of constraint node', abs( ierr ) )
       !
    ENDDO
    !
    RETURN
    !
    !
10  CALL errore( 'card_xml_constraints', 'error reading data inside constraint node', i )
    !
    !
  END SUBROUTINE card_xml_constraints
  !
  !
  !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !                                                                         !
  ! CLIMBING_IMAGES (optional)                                              !
  !                                                                         !
  !   Needed to explicitly specify which images have to climb               !
  !                                                                         !
  ! Syntax:                                                                 !
  !                                                                         !
  !   <climbing_images>                                                     !
  !      <images>                                                           !
  !        <integer rank=1 n1="N">                                          !
  !         index1                                                          !
  !         index2                                                          !
  !         ...                                                             !
  !         indexN                                                          !
  !        </integer>
  !      </images>                                                          !
  !   </climbing_images>                                                    !
  !                                                                         !
  !                                                                         !
  ! Where:                                                                  !
  !                                                                         !
  !   index1, ..., indexN are indices of the images that have to climb      !
  !                                                                         !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !
  SUBROUTINE card_xml_climbing_images( )
!    !
!    IMPLICIT NONE
!    ! 
!    ! 
!    INTEGER          :: i, num_climb_images, ierr
!    INTEGER, DIMENSION(:), ALLOCATABLE :: tmp
!    CHARACTER (LEN=iotk_attlenx)  :: attr
!    !
!    !
!    IF ( CI_scheme == 'manual' ) THEN
!       !
!       IF ( allocated( climbing ) ) deallocate( climbing )
!       !
!       allocate( climbing( num_of_images ) )   
!       !
!       climbing( : ) = .FALSE.
!       !
!       CALL iotk_scan_begin( xmlinputunit, 'images', ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_climbing_images', 'error scanning begin of &
!            &images node', abs( ierr ) )
!       !
!       CALL iotk_scan_begin( xmlinputunit, 'integer', attr, ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_climbing_images', 'error scanning begin of &
!            &integer node', abs( ierr ) )
!       !
!       CALL iotk_scan_end( xmlinputunit, 'integer', ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_climbing_images', 'error scanning end of &
!            &integer node', abs( ierr ) )
!       !
!       CALL iotk_scan_attr( attr, 'n1', num_climb_images, ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_climbing_images', 'error reading n1 attribute of &
!            &integer node', abs( ierr ) )
!       !
!       IF ( num_climb_images < 1 ) CALL errore( 'card_xml_climbing_images', 'non positive value &
!            &of num_climb_images', abs( num_climb_images ) )
!       !
!       allocate( tmp( num_climb_images ) )
!       !
!       CALL iotk_scan_dat_inside( xmlinputunit, tmp, ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_climbing_images', 'error reading data inside &
!            &images node', abs( ierr ) )
!       !
!       CALL iotk_scan_end( xmlinputunit, 'images', ierr = ierr )
!       IF ( ierr /= 0 ) CALL errore( 'card_xml_climbing_images', 'error scanning end of &
!            &images node', abs( ierr ) )
!       !
!       DO i = 1, num_climb_images
!          !
!          IF ( ( tmp(i) > num_of_images ) .or. ( tmp(i)<0 ) ) CALL errore('card_xml_climbing_images',&
!               "image that doesn't exist", 1 )
!          !
!          climbing(tmp(i)) = .true.
!          !
!       ENDDO
!       !
!    ENDIF
!    !
    RETURN
    !
    !
  END SUBROUTINE card_xml_climbing_images
  !
  !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !                                                                         !
  ! PLOT_WANNIER (optional)                                                 !
  !                                                                         !
  !   Needed to specify the indices of the wannier functions that           !
  !   have to be plotted                                                    !
  !                                                                         !
  ! Syntax:                                                                 !
  !                                                                         !
  !   <plot_wannier>                                                        !
  !     <wf_list>                                                           !
  !       <integer rank="1" n1="N">                                         !
  !         index1                                                          !
  !         .....                                                           !
  !         indexN                                                          !
  !       </integer>                                                        !
  !     </wf_list>                                                          !
  !   </plot_wannier>                                                       !
  !                                                                         !
  ! Where:                                                                  !
  !                                                                         !
  !   index1, ..., indexN are indices of the wannier functions              !
  !                                                                         !
  !                                                                         !
  !                                                                         !
  !_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_!
  !
  SUBROUTINE card_xml_plot_wannier( )
    !
    IMPLICIT NONE
    ! 
    ! 
    INTEGER          :: i, j, ib, ni, ierr
    INTEGER, DIMENSION(:), ALLOCATABLE :: tmp
    CHARACTER (LEN=iotk_attlenx)  :: attr
    !
    !
    !
    CALL iotk_scan_begin( xmlinputunit, 'wf_list', ierr = ierr )
    IF ( ierr /= 0 ) CALL errore( 'card_xml_plot_wannier', 'error scanning begin of &
         &wf_list node', abs( ierr ) )
    !
    IF ( nwf > 0 ) THEN
       CALL iotk_scan_begin( xmlinputunit, 'integer', attr, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_plot_wannier', 'error scanning begin of &
            &integer node', abs( ierr ) )
       !
       CALL iotk_scan_end( xmlinputunit, 'integer', ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_plot_wannier', 'error scanning end of &
            &integer node', abs( ierr ) )
       !
       CALL iotk_scan_attr( attr, 'n1', ni , ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_plot_wannier', 'error reading n1 attribute of &
            &integer node', abs( ierr ) )
       !
       IF ( (ni < 1) .or. (ni > nwf) ) CALL errore( 'card_xml_plot_wannier', 'invalid value &
            &of n1', abs( ni ) )
       !
       allocate( tmp( ni ) )
       !
       CALL iotk_scan_dat_inside( xmlinputunit, tmp, ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_plot_wannier', 'error reading data inside &
            & data', abs( ierr ) )
       !
       CALL iotk_scan_end( xmlinputunit, 'wf_list', ierr = ierr )
       IF ( ierr /= 0 ) CALL errore( 'card_xml_plot_wannier', 'error scanning end of &
            &wf_list node', abs( ierr ) )
       !
       ! ordering in ascending order
       ib = 1
       DO j = 1, nwf
          !
          DO i = 1, ni
             IF ( tmp(i) == j ) THEN
                wannier_index(ib) = j
                ib = ib + 1
             ENDIF
          ENDDO
          !
       ENDDO
       !
       deallocate( tmp )
       !
    ENDIF
    !
    RETURN
    !
  END SUBROUTINE card_xml_plot_wannier
  !
END MODULE read_xml_cards_module
