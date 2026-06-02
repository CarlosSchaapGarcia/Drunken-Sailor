const bars = [
  {
    name: "Eetcafé Sfeer",
    latitude: 52.7869678,
    longitude: 6.8881106,
    gay_friendly: false,
    hours: {
      monday:    null,
      tuesday:   { open: "14:00", close: "22:00" },
      wednesday: { open: "14:00", close: "22:00" },
      thursday:  { open: "14:00", close: "22:00" },
      friday:    { open: "10:00", close: "22:00" },
      saturday:  { open: "10:00", close: "22:00" },
      sunday:    { open: "00:00", close: "24:00" }, // open 24h
    }
  },

  {
    name: "Café De drie Paardjes",
    latitude: 52.7869678,
    longitude: 6.8881106,
    gay_friendly: false,
    hours: {
      monday:    null,
      tuesday:   { open: "11:00", close: "21:00" },
      wednesday: { open: "11:00", close: "21:00" },
      thursday:  { open: "11:00", close: "21:00" },
      friday:    { open: "09:00", close: "01:00" },
      saturday:  { open: "10:00", close: "01:00" },
      sunday:    { open: "11:00", close: "18:00" },
    }
  },

  {
    name: "Zwetser Eten & Drinken",
    latitude: 52.7862986,
    longitude: 6.8905768,
    gay_friendly: false,
    hours: {
      monday:    { open: "11:00", close: "23:00" },
      tuesday:   { open: "10:00", close: "23:00" },
      wednesday: { open: "10:00", close: "24:00" },
      thursday:  { open: "10:00", close: "24:00" },
      friday:    { open: "10:00", close: "01:00" },
      saturday:  { open: "10:00", close: "01:00" },
      sunday:    { open: "11:00", close: "23:00" },
    }
  },

  {
    name: "Thijs & Co",
    latitude: 52.7837996,
    longitude: 6.8879797,
    gay_friendly: false,
    hours: {
      monday:    null,
      tuesday:   null,
      wednesday: { open: "12:00", close: "23:00" },
      thursday:  { open: "12:00", close: "23:00" },
      friday:    { open: "12:00", close: "01:00" },
      saturday:  { open: "12:00", close: "01:00" },
      sunday:    { open: "12:00", close: "23:00" },
    }
  },

  {
    name: "Tranquilo",
    latitude: 52.7837996,
    longitude: 6.8879797,
    gay_friendly: false,
    hours: null // temporarily closed
  },

  {
    name: "ATLAS Café",
    latitude: 52.7837996,
    longitude: 6.8879797,
    gay_friendly: false,
    hours: null // no hours available
  },

  {
    name: "Snooker & Pool Center Emmen",
    latitude: 52.7837996,
    longitude: 6.8879797,
    gay_friendly: false,
    hours: {
      monday:    { open: "18:00", close: "24:00" },
      tuesday:   { open: "18:00", close: "24:00" },
      wednesday: { open: "18:00", close: "24:00" },
      thursday:  { open: "18:00", close: "24:00" },
      friday:    { open: "18:00", close: "01:00" },
      saturday:  { open: "14:00", close: "01:00" },
      sunday:    { open: "14:00", close: "24:00" },
    }
  },

  {
    name: "Cafe De Gouden Leeuw Emmen",
    latitude: 52.7837996,
    longitude: 6.8879797,
    gay_friendly: false,
    hours: {
      monday:    { open: "17:00", close: "24:00" },
      tuesday:   { open: "17:00", close: "24:00" },
      wednesday: { open: "17:00", close: "24:00" },
      thursday:  { open: "17:00", close: "24:00" },
      friday:    { open: "15:00", close: "24:00" },
      saturday:  { open: "15:00", close: "24:00" },
      sunday:    { open: "15:00", close: "24:00" },
    }
  },

  {
    name: "Bar Hop 1.6",
    latitude: 52.7837996,
    longitude: 6.8879797,
    gay_friendly: false,
    hours: {
      monday:    null,
      tuesday:   null,
      wednesday: { open: "17:00", close: "24:00" },
      thursday:  { open: "17:00", close: "01:00" },
      friday:    { open: "17:00", close: "02:00" },
      saturday:  { open: "17:00", close: "02:00" },
      sunday:    { open: "17:00", close: "24:00" },
    }
  },

  {
    name: "MilaDo",
    latitude: 52.7837996,
    longitude: 6.8879797,
    gay_friendly: false,
    hours: {
      monday:    { open: "12:00", close: "16:30" },
      tuesday:   { open: "11:00", close: "17:30" },
      wednesday: { open: "11:00", close: "17:30" },
      thursday:  { open: "11:00", close: "19:30" },
      friday:    { open: "10:00", close: "18:00" },
      saturday:  { open: "10:00", close: "17:00" },
      sunday:    null,
    }
  },

  {
    name: "Restaurant ByZoo",
    latitude: 52.7837996,
    longitude: 6.8879797,
    gay_friendly: false,
    hours: {
      monday:    { open: "07:00", close: "23:00" },
      tuesday:   { open: "07:00", close: "23:00" },
      wednesday: { open: "07:00", close: "23:00" },
      thursday:  { open: "07:00", close: "23:00" },
      friday:    { open: "07:00", close: "23:00" },
      saturday:  { open: "08:00", close: "23:00" },
      sunday:    { open: "08:00", close: "23:00" },
    }
  },
];

module.exports = { bars };
