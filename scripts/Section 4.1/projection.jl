using Polyhedra, CDDLib

## projections
function projection(m)
    relax_integrality(m)
    poly = polyhedron(m, CDDLib.Library(:exact))
    removehredundancy!(poly)
    proj = project(poly, 1:2)
    removehredundancy!(proj)

    return proj
end
area = Polyhedra.volume