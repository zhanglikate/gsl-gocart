module plume_zero_mod


  use gsd_chem_constants, only : kind_chem
  implicit none
  integer, parameter :: nkp = 200, ntime = 200

  type plumegen_coms
    logical :: initialized = .false.

    real(kind=kind_chem),dimension(nkp) ::  w,t,qv,qc,qh,qi,sc,  &  ! blob
         vth,vti,rho,txs,  &
         est,qsat! never used: ,qpas,qtotal

    real(kind=kind_chem),dimension(nkp) ::  wc,wt,tt,qvt,qct,qht,qit,sct
    real(kind=kind_chem),dimension(nkp) ::  dzm,dzt,zm,zt,vctr1,vctr2 &
         ,vt3dc,vt3df,vt3dk,vt3dg,scr1

    real(kind=kind_chem),dimension(nkp) ::  pke,the,thve,thee,pe,te,qvenv,dne ! environment at plume grid ! never used: rhe, sce
    real(kind=kind_chem),dimension(nkp) ::  ucon,vcon,thtcon ,rvcon,picon,tmpcon & ! never used: wcon, dncon, prcon
         ,zcon,zzcon ! environment at RAMS  grid ! never used: scon

    real(kind=kind_chem) :: DZ,DQSDZ,VISC(nkp),VISCOSITY,TSTPF   
    integer :: N,NM1,L
    !
    real(kind=kind_chem) :: CVH(nkp),CVI(nkp),ADIABAT,&
         WBAR,VHREL,VIREL  ! advection
    ! Never used: ADVW,ADVT,ADVV,ADVC,ADVH,ADVI,ALAST(10)

    !
    real(kind=kind_chem) :: ZSURF,ZTOP ! never used: ZBASE
    ! never used: integer :: LBASE
    !
    real(kind=kind_chem) :: AREA,RSURF,ALPHA,RADIUS(nkp)  ! entrain
    !
    real(kind=kind_chem) :: HEATING(ntime),FMOIST,BLOAD   ! heating
    !
    real(kind=kind_chem) :: DT,TIME,TDUR
    integer :: MINTIME,MDUR,MAXTIME
    !
    !REAL(kind=kind_chem),DIMENSION(nkp,2)  :: W_VMD,VMD
    REAL(kind=kind_chem) :: upe   (nkp)
    REAL(kind=kind_chem) :: vpe   (nkp)
    REAL(kind=kind_chem) :: vel_e (nkp)

    REAL(kind=kind_chem) :: vel_p (nkp)
    REAL(kind=kind_chem) :: rad_p (nkp)
    REAL(kind=kind_chem) :: vel_t (nkp)
    REAL(kind=kind_chem) :: rad_t (nkp)

    REAL(kind=kind_chem) :: ztop_(ntime)
    integer :: testval
  contains
    procedure :: set_to_zero => plumegen_coms_zero
  end type plumegen_coms

  type(plumegen_coms), private, pointer :: private_thread_coms

!$OMP THREADPRIVATE(private_thread_coms)

contains

  function get_thread_coms() result(coms)
    implicit none
    class(plumegen_coms), pointer :: coms
    if(.not.associated(private_thread_coms)) then
      allocate(private_thread_coms)
      call plumegen_coms_zero(private_thread_coms)
    endif
    coms => private_thread_coms
  end function get_thread_coms

  subroutine plumegen_coms_zero(this)
    implicit none
    class(plumegen_coms) :: this

    this%initialized = .false.

    this%w=0.0
    this%t=0.0
    this%qv=0.0
    this%qc=0.0
    this%qh=0.0
    this%qi=0.0
    this%sc=0.0
    this%vth=0.0
    this%vti=0.0
    this%rho=0.0
    this%txs=0.0
    this%est=0.0
    this%qsat=0.0
    !this%qpas=0.0
    !this%qtotal=0.0
    this%wc=0.0
    this%wt=0.0
    this%tt=0.0
    this%qvt=0.0
    this%qct=0.0
    this%qht=0.0
    this%qit=0.0
    this%sct=0.0
    this%dzm=0.0
    this%dzt=0.0
    this%zm=0.0
    this%zt=0.0
    this%vctr1=0.0
    this%vctr2=0.0
    this%vt3dc=0.0
    this%vt3df=0.0
    this%vt3dk=0.0
    this%vt3dg=0.0
    this%scr1=0.0
    this%pke=0.0
    this%the=0.0
    this%thve=0.0
    this%thee=0.0
    this%pe=0.0
    this%te=0.0
    this%qvenv=0.0
    !this%rhe=0.0
    this%dne=0.0
    !this%sce=0.0 
    this%ucon=0.0
    this%vcon=0.0
    !this%wcon=0.0
    this%thtcon =0.0
    this%rvcon=0.0
    this%picon=0.0
    this%tmpcon=0.0
    !this%dncon=0.0
    !this%prcon=0.0 
    this%zcon=0.0
    this%zzcon=0.0
    !this%scon=0.0 
    this%dz=0.0
    this%dqsdz=0.0
    this%visc=0.0
    this%viscosity=0.0
    this%tstpf=0.0
    !this%advw=0.0
    !this%advt=0.0
    !this%advv=0.0
    !this%advc=0.0
    !this%advh=0.0
    !this%advi=0.0
    this%cvh=0.0
    this%cvi=0.0
    this%adiabat=0.0
    this%wbar=0.0
    !this%alast=0.0
    this%vhrel=0.0
    this%virel=0.0  
    this%zsurf=0.0
    !this%zbase=0.0
    this%ztop=0.0
    this%area=0.0
    this%rsurf=0.0
    this%alpha=0.0
    this%radius=0.0
    this%heating=0.0
    this%fmoist=0.0
    this%bload=0.0
    this%dt=0.0
    this%time=0.0
    this%tdur=0.0
    this%ztop_=0.0
    this%upe =0.0  
    this%vpe =0.0  
    this%vel_e =0.0
    this%vel_p =0.0
    this%rad_p =0.0
    this%vel_t =0.0
    this%rad_t =0.0
    !this%W_VMD=0.0
    !this%VMD=0.0
    this%n=0
    this%nm1=0
    this%l=0
    !this%lbase=0
    this%mintime=0
    this%mdur=0
    this%maxtime=0
  end subroutine plumegen_coms_zero
end module plume_zero_mod
