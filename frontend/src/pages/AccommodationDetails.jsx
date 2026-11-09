import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import TravelerShell, { Loader } from "../components/TravelerShell";
import { apiFetch } from "../services/api";

const fallbackPhoto = "/hotel-fallback.jpg";

export default function AccommodationDetails() {
  const { tripId, accommodationId } = useParams();
  const [result, setResult] = useState(null);

  useEffect(() => {
    let active = true;

    apiFetch(`/traveler/accommodations/${accommodationId}`)
      .then((hotel) => {
        if (active) setResult({ accommodationId, hotel });
      })
      .catch((error) => {
        if (active) setResult({ accommodationId, error: error.message });
      });

    return () => {
      active = false;
    };
  }, [accommodationId]);

  const details = result?.accommodationId === accommodationId ? result : null;
  const hotel = details?.hotel;

  return (
    <TravelerShell
      eyebrow="STAYS"
      title={hotel?.name || "Accommodation details"}
      subtitle={hotel?.address || "View property information"}
    >
      <Link to={`/traveler/trips/${tripId}/accommodations`}>
        ← Back to accommodations
      </Link>

      {!details && <Loader />}
      {details?.error && <p role="alert">{details.error}</p>}

      {hotel && (
        <article className="content-card">
          <img
            key={accommodationId}
            src={hotel.images?.[0]?.image_url || fallbackPhoto}
            alt={hotel.images?.[0]?.image_url ? hotel.name : ""}
            style={{ width: "100%", maxHeight: 360, objectFit: "cover" }}
            onError={(event) => {
              const image = event.currentTarget;
              if (image.getAttribute("src") !== fallbackPhoto) {
                image.src = fallbackPhoto;
                image.alt = "";
              }
            }}
          />

          <h2>{hotel.name}</h2>
          <p>{hotel.description || "No description available."}</p>
          {hotel.address && <p>Address: {hotel.address}</p>}
          {hotel.star_rating != null && <p>Rating: {hotel.star_rating} stars</p>}
          {hotel.check_in_time && <p>Check-in: {hotel.check_in_time}</p>}
          {hotel.check_out_time && <p>Check-out: {hotel.check_out_time}</p>}
        </article>
      )}
    </TravelerShell>
  );
}