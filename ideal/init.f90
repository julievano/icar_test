module init
	use data_structures
	use io_routines
	use geo
	
	implicit none
	private
	public::init_model
	
contains
	subroutine init_model(options_filename,options,domain,boundary)
		implicit none
		character(len=*), intent(in) :: options_filename
		type(options_type), intent(out) :: options
		type(domain_type), intent(out):: domain
		type(bc_type), intent(out):: boundary
		
! 		read in options file
		write(*,*) "Init Options"
		call init_options(options_filename,options)
! 		allocate and initialize the domain
		write(*,*) "Init Domain"
		call init_domain(options,domain)
! 		allocate and initialize the boundary conditions structure (includes 3D grids too...)
!		this might be more apropriately though of as a forcing data structure (for low res model)
		write(*,*) "Init Boundaries"
		call init_bc(options,domain,boundary)
		write(*,*) "Finished Initialization"
		
	end subroutine init_model
	
	subroutine init_options(options_filename,options)
! 		reads a series of options from a namelist file and stores them in the 
! 		options data structure
		implicit none
		character(len=*), intent(in) :: options_filename
		type(options_type), intent(out) :: options
		
		character(len=100) :: init_conditions_file, output_file, boundary_file
		character(len=100) :: latvar,lonvar
		real :: dx,outputinterval,dz
		integer :: name_unit,ntimesteps
		integer :: pbl,lsm,mp,rad,conv,adv,wind,nz
		logical :: readz,debug
		
! 		set up namelist structures
		namelist /files_list/ init_conditions_file,output_file,boundary_file
		namelist /var_list/ latvar,lonvar
		namelist /parameters/ ntimesteps,outputinterval,dx,readz,nz,debug,dz
		namelist /physics/ pbl,lsm,mp,rad,conv,adv,wind
		
! 		read namelists
		open(io_newunit(name_unit), file=options_filename)
		read(name_unit,nml=files_list)
		read(name_unit,nml=var_list)
		read(name_unit,nml=parameters)
		read(name_unit,nml=physics)
		close(name_unit)
		
! 		could probably simplify and read these all right from the namelist file, 
! 		but this way we can change the names in the file independant of the internal variable names
		options%init_conditions_file=init_conditions_file
		options%boundary_file=boundary_file
		options%output_file=output_file
		options%latvar=latvar
		options%lonvar=lonvar
		options%ntimesteps=ntimesteps
		options%io_dt=outputinterval
		options%dx=dx
		options%dz=dz
		options%readz=readz
		options%nz=nz
		options%debug=debug
		options%physics%boundarylayer=pbl
		options%physics%convection=conv
		options%physics%advection=adv
		options%physics%landsurface=lsm
		options%physics%microphysics=mp
		options%physics%radiation=rad
		options%physics%windtype=wind
		
	end subroutine init_options
	
	subroutine remove_edges(domain,edgesize)
		type(domain_type), intent(inout) :: domain
		integer, intent(in)::edgesize
		
		write(*,*) "reduce edges here..."
		
	end subroutine remove_edges
			
	subroutine init_domain(options, domain)
		implicit none
		type(options_type), intent(in) :: options
		type(domain_type), intent(out):: domain
		integer:: ny,nz,nx,i
		
! 		these are the only required variables on a high-res grid, lat, lon, and terrain elevation
		call io_read2d(options%init_conditions_file,"HGT",domain%terrain,1)
		call io_read2d(options%init_conditions_file,options%latvar,domain%lat,1)
		call io_read2d(options%init_conditions_file,options%lonvar,domain%lon,1)
		
		if(options%buffer>0) then
			call remove_edges(domain,options%buffer)
		endif
! 		use the lat variable to define the x and y dimensions for all other variables
		nx=size(domain%lat,1)
		ny=size(domain%lat,2)
! 		assumes nz is defined in the options
		nz=options%nz
		
! 		if a 3d grid was also specified, then read those data in
		if (options%readz) then
			if (options%debug) then
				write(*,*) "Reading 3D Z data"
			endif
			call io_read3d(options%init_conditions_file,"z", domain%z)
! 			dz also has to be calculated from the 3d z file
			allocate(domain%dz(nx,nz,ny))
			domain%dz(:,1:nz-1,:)=domain%z(:,2:nz,:)-domain%z(:,1:nz-1,:)
			domain%dz(:,nz,:)=domain%dz(:,nz-1,:)
		else
! 			otherwise, set up the z grid to be evenly spaced in z using the terrain +dz/2 for the base
! 			and z[1]+i*dz for the res
			allocate(domain%z(nx,nz,ny))
			do i=1,nz
				domain%z(:,i,:)=domain%terrain+(i*options%dz)-(options%dz/2)
			enddo
! 			here dz is just constant, but must be on a 3d grid for microphysics code
			allocate(domain%dz(nx,nz,ny))
			domain%dz=options%dz
		endif
		if (options%debug) then
			write(*,*) "allocating domain wide memory"
		endif
! 		all other variables should be allocated and initialized to 0
		allocate(domain%p(nx,nz,ny))
		domain%p=0
		allocate(domain%u(nx,nz,ny))
		domain%u=0
		allocate(domain%v(nx,nz,ny))
		domain%v=0
		allocate(domain%th(nx,nz,ny))
		domain%th=0
		allocate(domain%qv(nx,nz,ny))
		domain%qv=0
		allocate(domain%cloud(nx,nz,ny))
		domain%cloud=0
		allocate(domain%w(nx,nz,ny))
		domain%w=0
		allocate(domain%ice(nx,nz,ny))
		domain%ice=0
		allocate(domain%nice(nx,nz,ny))
		domain%nice=0
		allocate(domain%qrain(nx,nz,ny))
		domain%qrain=0
		allocate(domain%nrain(nx,nz,ny))
		domain%nrain=0
		allocate(domain%qsnow(nx,nz,ny))
		domain%qsnow=0
		allocate(domain%qgrau(nx,nz,ny))
		domain%qgrau=0
		allocate(domain%rain(nx,ny))
		domain%rain=0
		allocate(domain%snow(nx,ny))
		domain%snow=0
		allocate(domain%graupel(nx,ny))
		domain%graupel=0
		
! 		store dx in domain as well as options, read as an option, but it is more appropriate in domain
		domain%dx=options%dx
		
	end subroutine init_domain
	
	subroutine init_bc_data(options,boundary,domain)
		implicit none
		type(options_type), intent(in) :: options
		type(bc_type), intent(out):: boundary
		type(domain_type), intent(in):: domain
		integer::nx,ny,nz
		
! 		these variables are required for any boundary/forcing file type
		call io_read2d(options%boundary_file,options%latvar,boundary%lat)
		call io_read2d(options%boundary_file,options%lonvar,boundary%lon)
		call io_read2d(options%boundary_file,"HGT",boundary%terrain)
		
		nx=size(domain%lat,1)
		nz=options%nz
		ny=size(domain%lat,2)
! 		all other structures must be allocated and initialized, but will be set on a forcing timestep
! 		this also makes it easier to change how these variables are read from various forcing model file structures
		allocate(boundary%dudt(nx,nz,ny))
		boundary%dudt=0
		allocate(boundary%dvdt(nx,nz,ny))
		boundary%dvdt=0
		allocate(boundary%dwdt(nx,nz,ny))
		boundary%dwdt=0
		allocate(boundary%dpdt(nx,nz,ny))
		boundary%dpdt=0
		allocate(boundary%dthdt(nz,max(nx,ny),4))
		boundary%dthdt=0
		allocate(boundary%dqvdt(nz,max(nx,ny),4))
		boundary%dqvdt=0
		allocate(boundary%dqcdt(nz,max(nx,ny),4))
		boundary%dqcdt=0
		
	end subroutine init_bc_data
	
	subroutine interpolate_topo(bc,domain)
		type(bc_type), intent(inout) :: bc
		type(domain_type), intent(in) :: domain
		real, allocatable, dimension(:,:)::terrain_temp
		integer::nx1,ny1,nx2,ny2
! 		nx1=size(domain%terrain,1)
! 		ny1=size(domain%terrain,2)
! 		nx2=size(bc%terrain,1)
! 		ny2=size(bc%terrain,2)
! 		allocate(terrain_temp(nx2,ny2))
! 		terrain_temp=bc%terrain
! 		deallocate(bc%terrain)
! 		allocate(bc%terrain(nx1,ny1))
		call geo_interp2d(bc%next_domain%terrain,bc%terrain,bc%geolut)
	end subroutine interpolate_topo
	
	subroutine init_bc(options,domain,boundary)
		implicit none
		type(options_type), intent(in) :: options
		type(domain_type), intent(in):: domain
		type(bc_type), intent(out):: boundary
			
! 		set up base data
		call init_bc_data(options,boundary,domain)
		call init_domain(options,boundary%next_domain) !set up a domain to hold the forcing for the next time step
! 		create the geographic look up table used to calculate boundary forcing data
		call geo_LUT(domain,boundary)
		
		call interpolate_topo(boundary,domain)
		
	end subroutine init_bc
end module
