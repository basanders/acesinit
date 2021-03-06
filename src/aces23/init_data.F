C
C  This program is free software; you can redistribute it and/or modify
C  it under the terms of the GNU General Public License as published by
C  the Free Software Foundation; either version 2 of the License, or
C  (at your option) any later version.

C  This program is distributed in the hope that it will be useful,
C  but WITHOUT ANY WARRANTY; without even the implied warranty of
C  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
C  GNU General Public License for more details.

C  The GNU General Public License is included in this distribution
C  in the file COPYRIGHT.
      subroutine init_data() 
      implicit none
      include 'int_gen_parms.h'
      include 'hess.h'
      include 'machine_types.h'
      include 'dbugcom.h'
      include 'trace.h'
      include 'dropmo.h'
      include 'sial_config_params.h'
      include 'basis_info.h'
      include 'ecp_info.h'
#ifdef ALTIX
      include 'sheap.h'
#endif

      integer*8 c_loc64
      integer moa, mob
      integer ntemp

      integer i, j, k, n, ierr, Ipr
      integer nalpha, npcoef
      integer dummy
      integer lnp1, lnpo
      integer ione
      integer nfct(max_centers), nufct(max_centers)
      integer naoatm(max_centers)
      integer npop(max_centers)
      integer ireorder(max_centers) 
      integer iqmstr_tmp(max_centers),jcostr_tmp(max_centers,Maxjco)
      integer nucstr_tmp(max_centers,Maxang,Maxjco)
      integer nrcstr_tmp(max_centers,Maxang,Maxjco)
      integer Jstrt_tmp(max_shells),Jrs_tmp(max_shells)
  
      integer nscfa_fock, nscfb_fock
      integer ieom_temprt, ieom_roots, iexcite     ! Watson Added
      integer ipolarizability, ig_tensor, ia_tensor! perera Added
      integer id_tensor                            ! perera Added
      integer iguess, ilshfta,  ilshftb, ibcc_conv
      integer idiis_start, idiis_order 
      integer idamp_type, idamp_tol,ilindep_tol,ilock_orbitals 
      integer iintgrl_tol, ilock_orbocc, idamp_end
      integer ijunk(100)
      integer iflags(500)

      character*4  atmnam(max_centers)
      Character*2  mtype(Max_centers)
      Character*80 Cnick(Max_centers)
      Character*80 Ecpnam(Max_centers)
    
      logical      cartesian
      logical      uhf
      logical dropit 
      logical*8        l8false

      common /flags/ iflags

      double precision dbuf(1), atom_coords(3,max_centers)
      double precision vnn, nuclear_nuclear_repulsion_energy

#ifdef ALTIX
      pointer (dptr, dbuf)
#else
      common dbuf
#endif

#ifdef ALTIX
      dptr = dshptr   ! set dbuf ptr to shared memory.
#endif

c-------------------------------------------------------------------------
c   scf_init() initializes the ACES II I/O subsystem so that JOBARC may 
c   be read.
c-------------------------------------------------------------------------

      call scf_init(vnn)
      Write(6,*) "after scf_init"

c-------------------------------------------------------------------------
c   Read original MOL file, create a new one with the subshells split.
c   The new MOL file will be named CHSSI.MOL, and we will work from
c   CHSSI.MOL from this point on.
c
c   This will allow us to perform finer segmentation of the AO indices 
c   later on.
c-------------------------------------------------------------------------

c      call segment_mol(molfile, 'CHSSI.MOL', 12, 13, iErr)
c      if (ierr .ne. 0) then
c         print *,'Error: Cannot process ',molfile
c         print *,'Error code ',ierr
c         call abort_job()
c      endif

c-------------------------------------------------------------------------
c   Inspect the MOL file to determine problem size.  Contraction 
c   coefficients and exponents are not read in at this stage.
c-------------------------------------------------------------------------

CDEBUG      call simple_inspect_mol('CHSSI.MOL', max_centers, max_shells, 

      IECP_ON = iflags(71)

      call simple_inspect_mol('MOL', max_centers, max_shells, 
     *           ncenters, nshells, nspc, 
     *           cartesian, ITFCT, LNP1, LNPO, Nfct,
     *           nufct, nbasis, naobasis, nCFPS, nPFpS,
     *           naoatm, ivAngMom, atom, 
     *
     *           Iecp_on, Maxang, Maxjco, Nucstr_tmp, Nrcstr_tmp, 
     *           Iqmstr_tmp, 
     *           Jcostr_tmp, jstrt_tmp, Jrs_tmp, Atmnam, Charge)

#ifdef _DEBUG_LVL0
C---
      Write(6,"(a,a,7(1x,I4))") "natoms,nshells,ITFCT,LNP1,lnpo",
     &                          "nbasis,NAOBASIS:",ncenters,nshells,
     &                                         ITFCT,LNP1,lnpo,
     &                                        nbasis,NAOBASIS
      Write(6,*) "Entering inspect mol", iecp_on
      Write(6,*)
      Write(6,"(a)") "The number of con. function per shell"
      Write(6,"(10(1x,I4))") (nCFpS(i), i=1, nshells)
      Write(6,"(a)") "The number of prim. function per shell"
      Write(6,"(10(1x,I4))") (nPFpS(i), i=1, nshells)
      Write(6,"(a)") "The Iqmstr"
      Write(6,"(10(1x,I4))") (Iqmstr_tmp(i), i=1, ncenters)
      Write(6,"(a)") "The jcostr"
      Do i=1, Ncenters
        Write(6,"(10(1x,I4))") (jcostr_tmp(i,j),j=1,4)
      Enddo
      Write(6,"(a)") "The Nucstr"
      Do i=1, Ncenters
        Write(6,"(10(1x,I4))") ((Nucstr_tmp(i,j,k),j=1,4),k=1,Maxjco)
      Enddo
      Write(6,"(a)") "The Nrcstr"
      Do i=1, Ncenters
        Write(6,"(10(1x,I4))") ((Nrcstr_tmp(i,j,k),j=1,4),k=1,Maxjco)
      Enddo
      Write(6,"(a)") "The jstrt"
      Write(6,"(10(1x,I4))") (Jstrt_tmp(i), i=1, Nshells)
      Write(6,"(a)") "The jrs"
      Write(6,"(10(1x,I4))") (Jrs_tmp(i), i=1, Nshells)
      Write(6,*)
#endif 
C
      write(6,*) ' NBASIS AFTER SIMPLE_INSPECT ', nbasis  
      if (cartesian) then
         ispherical = 0
      else
         ispherical = 1
      endif

      do i = 1, ncenters
         npop(i)     = 1
         ireorder(i) = i
      enddo

c---------------------------------------------------------------------------
C Compute the gradient of the Nuclear-Nuclear repulsion energy
C---------------------------------------------------------------------------

      call mem_alloc(dbuf, 9*ncenters*ncenters, bytes_per_double, 
     *               ix_hess, .true., ierr)
      if (ierr .ne. 0) then
         print *,'Error attempting to malloc hessian.'
         call abort_job ()
      endif 

      call mem_alloc(dbuf,  9*ncenters*ncenters, bytes_per_double, 
     *               ix_nnhess, .true., ierr)
      if (ierr .ne. 0) then
         print *,'Error attempting to malloc nuclear-nuclear hessian.'
         call abort_job ()
      endif 

      call nuclear_nuclear_gradient(dbuf(ix_hess), dbuf(ix_NNhess), 
     *                              ncenters)

c--------------------------------------------------------------------------
c   Allocate memory for exponents, coordinates, and basis functions.
c   and exponent dependent norm,
c--------------------------------------------------------------------------

      nalpha = 0
      npcoef = 0
      do i = 1, nshells
         nalpha = nalpha + npfps(i)
         npcoef = npcoef + npfps(i) * ncfps(i)
      enddo

      nalloc_pkg = 3*nshells + nalpha + npcoef 
      call mem_alloc(dbuf, nalloc_pkg, bytes_per_double, master_icoord, 
     *               .true., ierr)
      if (ierr .ne. 0) then
         print *,'Error attempting to malloc basis data.'
         call abort_job ()
      endif

      ialpha  = master_icoord + 3*nshells
      ipcoeff = ialpha  +  nalpha

      call mem_alloc(dbuf, nalpha, bytes_per_double, ialpha_norm,
     *               .true., ierr)
      if (ierr .ne. 0) then
         print *,'Error attempting to malloc basis data.'
         call abort_job ()
      endif

c-------------------------------------------------------------------------
c   Read orbital values from JOBARC.
c-------------------------------------------------------------------------

      ione = 1

      if ((.not. if_scf) .and. .not. dryrun) then
         call igetrec(1, 'JOBARC', 'OCCUPYA0', 1, nalpha_occupied)
         call dgetrec(1, 'JOBARC', 'SCFENEG',  ione, scf_energy)
         call dgetrec(1, 'JOBARC', 'TOTENERG',  ione, totenerg)
      else
         scf_energy = 0.
         totenerg = 0.
      endif
      noccupied       = nalpha_occupied

      call igetrec(1,'JOBARC','IFLAGS',100,iJunk)
      call igetrec(1,'JOBARC','IFLAGS2',500,iflags)

c------------------------------------------------------------------------
c   Retrieve flags parameters.
c------------------------------------------------------------------------

      iuhf = ijunk(11)
      if (dbg) print *,'IUHF = ',iuhf
      damp_init = ijunk(15) * .01
      scf_conv = 10.0d0**(-ijunk(5))
      cc_conv  = 10.0d0**(-ijunk(4))

      cc_iter = ijunk(7)
      if (cc_iter .eq. 0) then
         print *,'WARNING: ACES has defaulted cc_maxcyc to 0, ',
     *     ' resetting to 100.'
         cc_iter = 100
      endif

      cc_hist = ijunk(12)
      if (cc_hist .eq. 0) then
         print *,'WARNING: ACES has defaulted cc_exporder to 0,',
     *      ' resetting to 5.'
         cc_hist = 5
      endif

      cc_beg  = 2
      scf_iter = ijunk(16)
      scf_hist = ijunk(20)
      scf_beg  = ijunk(40)

c     Kluggy way of dealing with this VFL 1/2/2013 
C     No longer needed
C      if (scf_beg .ge. 8) then 
C         write(6,*) ' Resetting scf_beg to 2 '
C         scf_beg = 2 
C      endif 
C    The integral tolerance is moved to here from scflindep.h
C    Ajith Perera, 2/2015.
C    
      iintgrl_tol = iflags(108)
      intgrl_tol  = iintgrl_tol

      vib_freq_calc = .false. 
      if (ijunk(54) .ne. 0) vib_freq_calc = .true.
      vib_exact = .false.
      if (ijunk(54) .eq. 1) vib_exact = .true.
C
C Watson Added: For EOM calcs.
C
      iexcite = 0
      iexcite = ijunk(87)
      if (iexcite .gt. 0) then
         excite = DBLE(iexcite)
         eom_tol = 10.0d0**(-ijunk(98))
         call igetrec(-1, 'JOBARC', 'EESYMINF', 1, ieom_roots)
         write(*,*) ' ieom_roots: ', ieom_roots
         if (ieom_roots .eq. 0) then
            print *,'WARNING: ACES has defaulted ESTATE_SYM to 0, ',
     *        ' resetting to 4.'
            ieom_roots = 4
         endif
         eom_roots = DBLE(ieom_roots)
         ieom_temprt = ieom_roots
      endif
      if (iexcite .eq. 0) ieom_temprt = 0
C
C Watson
C
C Ajith Perera for second-order properties; 04/2014.
  
       iPolarizability = 0
       ia_tensor = 0
       ig_tensor = 0
       id_tensor = 0
       If (Ijunk(18) .EQ. 14 .OR. Ijunk(18) .EQ. 11) 
     &     iPolarizability = 1
       If (Ijunk(18) .EQ. 15 .OR. Ijunk(18) .EQ. 1) ia_tensor = 1
       If (Ijunk(18) .EQ. 16) ig_tensor = 1
       If (ijunk(18) .EQ. 17) id_tensor = 1
  
       polarizability = iPolarizability
       a_tensor       = ia_tensor
       g_tensor       = ig_tensor
       d_tensor       = id_tensor
C
C Ajith Perera, Bruecknere convergence criteria, 12/2014
C
        bcc_conv = ijunk(76)
        bcc_conv  = 10.0d0**(-ibcc_conv)
C 
C Initial SCF orbitals, level shifting parameters and damping.
C
        Iguess = ijunk(45)
        guess  = Iguess

        ilshfta = Iflags(111)
        ilshftb = Iflags(112)

        lshft_a1 = ilshfta
        lshft_b1 = ilshftb

        Idamp_type     = iflags(109)
        Idamp_tol      = iflags(110)
        Ilindep_tol    = ijunk(8)
        Ilock_orbitals = iflags(160)
        Ilock_orbocc   = ijunk(41)
        Idamp_end      = iflags(161)
        Idiis_start    = ijunk(40)
        Idiis_order    = ijunk(20)
  
  
        Damp_type     = Idamp_type
        Damp_tol      = Idamp_tol
        Lindep_tol    = Ilindep_tol
        Lock_orbitals = Ilock_orbitals
        Lock_orbocc   = Ilock_orbocc
        Damp_end      = Idamp_end
        Diis_start    = Idiis_start
        Diis_order    = Idiis_order
        
c-------------------------------------------------------------------------
c   Read IFLAGS2 off JOBARC.
c-------------------------------------------------------------------------

      call igetrec(1,'JOBARC','IFLAGS2',500,iJunk)

      geom_opt = .false.
      if (ijunk(5) .ne. 0) geom_opt = .true.

c------------------------------------------------------------------------
c   Allocate memory for the scf coefficient arrays, and read them in from
c   the ACES II JOBARC file.
c------------------------------------------------------------------------

      if ((.not. if_scf) .and. .not. dryrun) then
         call dgetrec(0,'JOBARC', 'SCFEVCA0', nscfa, dummy)   ! get reclen

         if (nscfa .lt. 0) then
            print *,'Error: ACES JOBARC file does not contain ',
     *           'SCFEVCA0 data'
            call abort_job()
         endif

         if (dbg) write(6,*) ' IUHF in init :', iuhf
         if (iuhf .eq. 2) then    ! ROHF
            call dgetrec(0,'JOBARC', 'FOCKA', nscfa_fock, dummy)

            if (nscfa_fock .lt. 0) then
               print *,'Error: ACES JOBARC file does not contain ',
     *           'FOCKA data'
               call abort_job()
            endif

            if (nscfa_fock .ne. nscfa) then
               print *,'Error: FOCKA has ',nscfa_fock,' elements, ',
     *            'should match SCFEVCA0 ',nscfa
               call abort_job()
            endif
         endif ! ROHF
      else
         nscfa = nbasis * nbasis 
      endif   

c---------------------------------------------------------------------------
c   If the gradient has been previously calculated (partially), read it 
c   from the JOBARC.
c---------------------------------------------------------------------------

      call dgetrec(0,'JOBARC', 'GRADIENT', n, dummy)

      if (n .gt. 0) then
          call dgetrec(1,'JOBARC', 'GRADIENT', n, gradient_data)
      else
         do i = 1, 3*ncenters
            gradient_data(i) = 0.
         enddo
      endif 
      
      call mem_alloc(dbuf, nscfa, bytes_per_double, iscfa, 
     *               .true., ierr)
      if (ierr .ne. 0) then
         print *,'mem_alloc for eigenvectors failed: nscfa = ',
     *     nscfa
         call abort_job()
      endif

      if ((.not. if_scf) .and. .not. dryrun) then
         call dgetrec(1, 'JOBARC', 'SCFEVCA0', nscfa, dbuf(iscfa))

c-------------------------------------------------------------------------
c   For ROHF, read in the FOCKA array.
c-------------------------------------------------------------------------

         if (iuhf .eq. 2) then   ! ROHF
            call mem_alloc(dbuf, nscfa, bytes_per_double,
     *                               ifockrohfa, .true., ierr)
            call dgetrec(1,'JOBARC','FOCKA', nscfa, dbuf(ifockrohfa))
         endif   ! ROHF
      endif

      if ((.not. if_scf) .and. .not. dryrun) then
         call dgetrec(0, 'JOBARC', 'SCFEVLA0', nepsa, dummy) 

         if (nepsa .lt. 0) then
             print *,'Error: ACES JOBARC file does not contain ',
     *          'SCFEVLA0 data.'
             call abort_job()
         endif
      else
         nepsa = nbasis
      endif

      call mem_alloc(dbuf, nepsa, bytes_per_double, iepsa, 
     *               .true., ierr)
      if (ierr .ne. 0) then
         print *,'mem_alloc for eigenvalues failed: nscfa = ',nscfa
         call abort_job()
      endif
     
      if ((.not. if_scf) .and. .not. dryrun) then
         call dgetrec(1, 'JOBARC', 'SCFEVLA0', nepsa, dbuf(iepsa))
      endif

c---------------------------------------------------------------------------
c   Look for beta spin data.
c---------------------------------------------------------------------------

      if (iuhf .eq. 0) then
         nscfb = -1
      else
         if ((.not. if_scf) .and. .not. dryrun) then
            call dgetrec(0,'JOBARC', 'SCFEVCB0', nscfb, dummy)   ! get reclen

            if (iuhf .eq. 2) then   ! ROHF
               call dgetrec(0,'JOBARC', 'FOCKB', nscfb_fock, dummy)

               if (nscfb_fock .le. 0) then
                  print *,'Error: FOCKB data is not on JOBARC'
                  call abort_job()
               endif

               if (nscfb_fock .ne. nscfb) then
                  print *,'Error: FOCKB has ',nscfb_fock,' elements,',
     *               ' should match SCFEVCB0 ',nscfb
                  call abort_job()
               endif
            endif   ! ROHF
         else
            nscfb = nbasis * nbasis
         endif
      endif

      if (nscfb .lt. 0) then

c-----------------------------------------------------------------------------
c   If ACES is telling us this is RHF, we must run a true RHF version of
c   the SCF SIAL code, then copy over the alpha-spin eigenvalue data into the
c   beta-spin eigenvalues.
c-----------------------------------------------------------------------------

         uhf = .false.
         nbeta_occupied = nalpha_occupied
         nscfb = nscfa
         print *,'*** WARNING: ACES has specified a RHF run. ',
     *      ' Either use REF=UHF in ACES or run a true RHF SIAL code.',
     *       '***'
      else
         uhf = .true.
      endif

      call mem_alloc(dbuf, nscfb, bytes_per_double, iscfb, 
     *                 .true., ierr)
      if (ierr .ne. 0) then
         print *,'mem_alloc for beta eigenvectors fialed: nscfb ',
     *     nscfb
         call abort_job()
      endif

      if (iuhf .eq. 2)
     *     call mem_alloc(dbuf, nscfb, bytes_per_double,
     *                                ifockrohfb, .true., ierr)

      if ((.not. if_scf) .and. uhf .and. .not. dryrun) then

c--------------------------------------------------------------------------
c  Read beta eigenvectors from JOBARC.
c--------------------------------------------------------------------------

         call dgetrec(1, 'JOBARC', 'SCFEVCB0', nscfb, dbuf(iscfb))

         if (iuhf .eq. 2) then   ! ROHF
            call dgetrec(1,'JOBARC','FOCKB', nscfb, dbuf(ifockrohfb))
         endif    ! ROHF
      else

c--------------------------------------------------------------------------
c   Copy alpha eigenvectors into the beta eigenvectors.
c--------------------------------------------------------------------------

         do i = 1, nscfa
            dbuf(iscfb+i-1) = dbuf(iscfa+i-1)
         enddo
      endif

      if ((.not. if_scf) .and. uhf .and. .not. dryrun) then

c---------------------------------------------------------------------------
c   Read number of beta eigenvalues from JOBARC.
c---------------------------------------------------------------------------

         call dgetrec(0, 'JOBARC', 'SCFEVLB0', nepsb, dummy)

         if (nepsb .lt. 0) then
             print *,'Error: ACES JOBARC file does not contain ',
     *           'SCFEVLB0 data.'
             call abort_job()
         endif
      else
         nepsb = nbasis 
      endif

      call mem_alloc(dbuf, nepsb, bytes_per_double, iepsb, 
     *                  .true., ierr)
      if (ierr .ne. 0) then
         print *,'mem_alloc for beta eigenvalues failed: nscfb ',nscfb
         call abort_job()
      endif

      if ((.not. if_scf) .and. uhf .and. .not. dryrun) then

c---------------------------------------------------------------------------
c   Read actual beta-spin eigenvalues from JOBARC.
c---------------------------------------------------------------------------

         call dgetrec(1, 'JOBARC', 'SCFEVLB0', nepsb, dbuf(iepsb))
      else

c--------------------------------------------------------------------------
c   Copy alpha-spin eigenvalues into beta-spin eigenvalues.
c--------------------------------------------------------------------------

         do i = 1, nepsb
            dbuf(iepsb+i-1) = dbuf(iepsa+i-1)
         enddo
      endif

      if ((.not. if_scf) .and. uhf .and. .not. dryrun) then
         call igetrec(1, 'JOBARC', 'OCCUPYB0', 1, nbeta_occupied)
      endif

      call read_basis_info('MOL', ncenters, ncenters, npop, 
     *           ireorder, cartesian, itfct, lnp1, lnpo, nfct, 
     *           nbasis, dbuf(ialpha), ixalpha,
     *           dbuf(ipcoeff), ixpcoef, atmnam, 
     *           dbuf(master_icoord),atom_coords,dbuf(ialpha_norm),
     *           naoatm)

#ifdef _DeBUG_LVL0
      Write(6,*)
      Write(6,"(a)") "The exponents"
      Write(6,"(5(1x,F15.8))") (Dbuf(Ialpha+i), i=0, Nalpha-1)
      Write(6,*)
      Write(6,"(a)") "The exponentsn norms"
      Write(6,"(5(1x,F15.8))") (Dbuf(Ialpha_norm+i), i=0, Nalpha-1)
      Write(6,*)
      Write(6,"(a)") "The contraction coefs"
      Write(6,"(5(1x,F15.8))") (dbuf(Ipcoeff+i), i=0, Npcoef-1)
      Write(6,*)
      Write(6,*) "Coordinates of shell"
      Write(6,"(5(1x,F15.8))") (dbuf(master_icoord+i),i=0,3*Nshells-1)
      Write(6,*)
      Write(6,*) "Coordinates of atoms"
      do k=1, Ncenters
      Write(6, "(3(1x,F12.8))") (atom_coords(i,k), i=1,3)
      enddo 
#endif 

C Read the ECP data file and fill arrays in ecp_info.h files. Those
C will be reread in setup_main and transfer into the .dat file. 

      If (Iecp_on .EQ. 1) then
         Ierr = 0
       
         call charges(CHARGE,mtype,natoms,ierr)

         If (Ierr .EQ. 0) Then
            Ipr = 0
            call ecpdef(natoms,mtype,Ecpnam,cnick) 
            call ecppar(ipr,cnick,CHARGE,natoms,.FALSE.,0)
         Else
            write(6,"(a)") 'E R R O R in subroutine chrges!'
            Call Errex 
         Endif
      Endif 

c-------------------------------------------------------------------------
c   If the SCF has already been performed check if MOs are to be dropped.
c-------------------------------------------------------------------------

      nalpha_virtual = nbasis - nalpha_occupied 
      nbeta_virtual  = nbasis - nbeta_occupied 

      write(6,*) ' NALPHA_VIRT =' , nalpha_virtual 
      write(6,*) ' NBETA_VIRT =' , nbeta_virtual 
      
C      if (.not. ignore_dropmo) then

C--------------------------------------------------------------------------
c   Check if any MO's are to be dropped.
C--------------------------------------------------------------------------

      CALL IGETREC(20,'JOBARC','NUMDROPA',1,NDROPMO_A)
      if (ndropmo_a .gt. 0) 
     *    CALL IGETREC(20,'JOBARC','MODROPA',NDROPMO_A,MODROP_A)

      if (ndropmo_a .gt. 0) then 

c----------------------------------------------------------------------------
c   Check to see if NUMDROPB is defined.  For RHF jobs, joda does not set it,
c   so we must copy over the alpha dropmo's in that case.
c----------------------------------------------------------------------------

         CALL IGETREC(0,'JOBARC','NUMDROPB',dummy, ndropmo_b)
         if (dummy .gt. 0) then   ! NUMDROPB is set.
            CALL IGETREC(20,'JOBARC','NUMDROPB',1,NDROPMO_B)
            if (ndropmo_b .gt. 0) 
     *         CALL IGETREC(20,'JOBARC','MODROPB',NDROPMO_B,MODROP_B)
         else   ! NUMDROPB is not set.

c-----------------------------------------------------------------------------
c   Copy over the alpha DROPMO values.
c-----------------------------------------------------------------------------

            ndropmo_b = ndropmo_a
            do i = 1, ndropmo_b
               modrop_b(i) = modrop_a(i)
            enddo
         endif
C      endif

      if ((ndropmo_a .gt. 0 .or. ndropmo_b .gt. 0) .and. 
     *    .not. ignore_dropmo) then 

C--------------------------------------------------------------------------
c   Reset the alpha eigenvectors if DROPMO. 
C--------------------------------------------------------------------------

         do j = 1, nbasis
            moamap(j) = 0
            mobmap(j) = 0 
         enddo

         moa = 0
         do j = 1, nbasis
            dropit = .false.

            do i = 1, ndropmo_a
               if (modrop_a(i) .eq. j) then
                  dropit = .true.
                  go to 11
               endif
            enddo

            moa = moa +1 
   11       continue

c------------------------------------------------------------------------
c   Move data for eigenvalue/eigenvector "j" to "moa".
c------------------------------------------------------------------------

            if (j .ne. moa .and. .not. dropit) then
               dbuf(iepsa+moa-1) = dbuf(iepsa+j-1)
               moamap(moa) = j 

               do i = 1, nbasis
                  dbuf(iscfa+nbasis*(moa-1)+i-1) = 
     *                 dbuf(iscfa+(j-1)*nbasis+i-1) 
               enddo
            endif
         enddo

C--------------------------------------------------------------------------
c   Reset the beta eigenvectors if DROPMO. 
C--------------------------------------------------------------------------

         if (ndropmo_b .gt. 0) then
            mob = 0 
            do j = 1, nbasis
               dropit = .false.

               do i = 1, ndropmo_b
                  if (modrop_b(i) .eq. j) then
                     dropit = .true.
                     go to 10
                  endif  
               enddo

               mob = mob +1 
   10          continue

c------------------------------------------------------------------------
c   Move data for eigenvalue/eigenvector "j" to "mob".
c------------------------------------------------------------------------

               if (j .ne. mob .and. .not. dropit) then
                  dbuf(iepsb+mob-1) = dbuf(iepsb+j-1)
                  mobmap(mob) = j 

                  do i = 1, nbasis
                     dbuf(iscfb+nbasis*(mob-1)+i-1) = 
     *                 dbuf(iscfb+(j-1)*nbasis+i-1) 
                  enddo
               endif
            enddo
         endif

C--------------------------------------------------------------------------
c   Reset the number of virtual orbitals if they were dropped. 
C--------------------------------------------------------------------------
c
C JNB: do not do virtual drop for fno sial program. 
         if(.not. if_fno) then
         nalpha_virtual = nbasis - nalpha_occupied    
         enalpha_virtual = nalpha_virtual
         do i = 1, ndropmo_a 
            if (modrop_a(i) .gt. nalpha_occupied) 
     *         nalpha_virtual = nalpha_virtual - 1  
         enddo 
c
         nbeta_virtual = nbasis - nbeta_occupied    
         enbeta_virtual = nbeta_virtual
         do i = 1, ndropmo_b 
            if (modrop_b(i) .gt. nbeta_occupied) 
     *      nbeta_virtual = nbeta_virtual - 1  
         enddo 
         endif
c
C--------------------------------------------------------------------------
c   Reset the number of occupied orbitals if they were dropped. 
C--------------------------------------------------------------------------
c
         enalpha_occupied = nalpha_occupied
         ntemp = nalpha_occupied 
         do i = 1, ndropmo_a 
            if (modrop_a(i) .le. nalpha_occupied) ntemp = ntemp - 1  
         enddo 
         nalpha_occupied = ntemp  
         nepsa           = nbasis - ndropmo_a   
c
         enbeta_occupied = nbeta_occupied
         ntemp = nbeta_occupied 
         do i = 1, ndropmo_b 
            if (modrop_b(i) .le. nbeta_occupied) ntemp = ntemp - 1  
         enddo 
         nbeta_occupied = ntemp  
         nepsb           = nbasis - ndropmo_b  

         write(6,*) ' Number of alpha virtuals = ', nalpha_virtual 
         write(6,*) ' Number of beta virtuals = ', nbeta_virtual 
         write(6,*) ' Number of alpha occupied = ',nalpha_occupied 
         write(6,*) ' Number of beta occupied = ',nbeta_occupied 

c
      endif ! ndropmo > 0 
c
      endif ! ((.not. ignore_dropmo then

c-------------------------------------------------------------------------
c   If we are running a SCF job, reset the energy variables and gradient
c   accumulation to 0.  The assumption is that this is the beginning of
c   a new gradient accumulation cycle.
c-------------------------------------------------------------------------

      if (if_scf .or. init_scf) then
         scf_energy = 0.
         totenerg   = 0.
         
         do i = 1, 3*ncenters
            gradient_data(i) = 0.
         enddo
      endif

      if (scf_energy .eq. 0.d0) then
C
C Compute the Nuclear-Nuclear repulsion energy
C --------------------------------------------
C
         vnn = nuclear_nuclear_repulsion_energy(nCenters)

         scf_energy = vnn
         print *,'SCF ENERGY IS INITIALIZED FROM ',
     *       'NUCLEAR-NUCLEAR REPULSION ENERGY: ',scf_energy
      endif

      print *,'--------- Required data from MOL file -----------'
      print *,'Number of centers.....................',nCenters
      print *,'Number of shells......................',nShells
      print *,'Cartesian flag........................',cartesian
      print *,'Total number of basis functions.......',nbasis
      print *,'Total number of primitive functions...',nalpha
      print *,'Initial SCF energy....................',scf_energy
      print *,'SCF damping factor....................',damp_init
      print *,'SCF convergence tolerance.............',scf_conv
      print *,'Number of SCF iterations..............',scf_iter
      print *,'Number of SCF histories for DIIS......',scf_hist
      print *,'Beginning iteration for SCF DIIS......',scf_beg
      print *,'CCSD convergence tolerance............',cc_conv
      print *,'Number of CCSD iterations.............',cc_iter
      print *,'Number of CCSD histories for DIIS.....',cc_hist
      print *,'Beginning iteration for CCSD DIIS.....',cc_beg
      print *,'Excited state computation.............',iexcite .gt. 0
      print *,'EOM-CCSD converged tolerance..........',eom_tol ! Watson added
      print *,'Number of EOM-CCSD roots to find......',ieom_temprt
      print *,'Geometry optimization calc............',geom_opt
      print *,'Vibrational frequency calc............',
     *                                  vib_freq_calc
  
      print *,'  Shell     Contracted fns.   Primitive Fns. '
      print *,'  -----     ---------------   --------------' 

      do i = 1, nshells
         print 200,i, nCFpS(i),nPFpS(i),
     *        (dbuf(master_icoord+(i-1)*3+j-1) ,j=1,3)
      enddo

      return
  100 format (1x,a4,3(2x,d14.6))
  200 format(2x,i4,12x,i3,15x,i3,3(1x,d20.12))

c     end subroutine init_data
      end
